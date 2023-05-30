defmodule AeMdw.Sync.AsyncTasks.WealthRankAccounts do
  @moduledoc false

  @typep micro_block :: term()

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Sync.Transaction

  require Model

  @spec dedup_pending_accounts() :: :ok
  def dedup_pending_accounts do
    state = State.new()

    {delete_keys, pubkeys_set} =
      state
      |> Collection.stream(Model.AsyncTask, nil)
      |> Stream.filter(fn {_ts, type} -> type == :store_acc_balance end)
      |> Stream.map(&State.fetch!(state, Model.AsyncTask, &1))
      |> Enum.map_reduce(MapSet.new(), fn
        Model.async_task(index: index, extra_args: []), acc ->
          {index, acc}

        Model.async_task(index: index, extra_args: [extra_args]), acc ->
          {index, MapSet.union(acc, extra_args)}
      end)

    with args when args != [] <- last_mb(state, nil) do
      task_index = {System.system_time(), :store_acc_balance}
      m_task = Model.async_task(index: task_index, args: args, extra_args: [pubkeys_set])

      State.commit_db(
        state,
        [
          DeleteKeysMutation.new(%{Model.AsyncTask => delete_keys}),
          WriteMutation.new(Model.AsyncTask, m_task)
        ],
        false
      )
    end

    :ok
  end

  @spec micro_block_accounts(micro_block(), [Mutation.t()]) :: MapSet.t()
  def micro_block_accounts(micro_block, mutations) do
    txs_pubkeys =
      micro_block
      |> :aec_blocks.txs()
      |> Enum.flat_map(fn signed_tx ->
        signed_tx
        |> Transaction.get_ids_from_tx()
        |> Enum.flat_map(fn
          {:id, :account, pubkey} -> [pubkey]
          _other -> []
        end)
      end)

    txs_pubkeys
    |> MapSet.new()
    |> MapSet.union(int_calls_accounts(mutations))
  end

  defp int_calls_accounts(mutations) do
    mutations
    |> Enum.filter(&is_struct(&1, IntCallsMutation))
    |> Enum.flat_map(fn %IntCallsMutation{int_calls: int_calls} ->
      int_calls
      |> Enum.filter(fn {_idx, fname, _type, _aetx, _tx} ->
        fname in ["Chain.spend", "Call.amount"]
      end)
      |> Enum.flat_map(fn {_idx, _fname, _type, aetx, _tx} ->
        aetx_accounts(aetx)
      end)
    end)
    |> MapSet.new()
  end

  defp aetx_accounts(aetx) do
    {tx_type, tx_rec} = :aetx.specialize_type(aetx)

    tx_type
    |> AeMdw.Node.tx_ids_positions()
    |> Enum.map(&elem(tx_rec, &1))
    |> Enum.flat_map(fn
      {:id, :account, pubkey} -> [pubkey]
      _other -> []
    end)
  end

  defp last_mb(state, key) do
    case State.prev(state, Model.Block, key) do
      {:ok, {_height, -1} = prev_key} ->
        last_mb(state, prev_key)

      {:ok, block_index} ->
        Model.block(hash: mb_hash) = State.fetch!(state, Model.Block, block_index)
        [mb_hash, block_index]

      :none ->
        []
    end
  end
end
