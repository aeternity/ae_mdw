defmodule AeMdw.Sync.AsyncTasks.WealthRankAccounts do
  @moduledoc false

  @typep micro_block :: term()

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Sync.Transaction

  require Model

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
end
