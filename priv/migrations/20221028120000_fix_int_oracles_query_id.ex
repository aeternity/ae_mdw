defmodule AeMdw.Migrations.FixIntOraclesQueryId do
  @moduledoc """
  Fixes the internal contract oracle query calls query IDs.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

  @fname "Oracle.query"

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(Model.FnameIntContractCall, {@fname, Util.min_int(), Util.min_int()})
      |> Stream.take_while(&match?({@fname, _call_txi, _local_idx}, &1))
      |> Stream.map(fn {@fname, call_txi, local_idx} ->
        Model.tx(block_index: block_index) = State.fetch!(state, Model.Tx, call_txi)

        {block_index, call_txi, local_idx}
      end)
      |> Stream.chunk_by(fn {block_index, _call_txi, _local_idx} -> block_index end)
      |> Stream.flat_map(fn [{block_index, _call_txi, _local_idx} | _rest] = chunk ->
        Model.block(hash: block_hash) = State.fetch!(state, Model.Block, block_index)

        fix_block_query_calls(state, block_hash, chunk)
      end)
      |> Stream.map(&WriteMutation.new(Model.IntContractCall, &1))
      |> Enum.to_list()

    _state = State.commit(state, mutations)

    IO.puts("DONE")

    {:ok, length(mutations)}
  end

  defp fix_block_query_calls(state, block_hash, calls_chunk) do
    {calls, _accounts_nonces} =
      Enum.map_reduce(calls_chunk, %{}, fn {_block_index, call_txi, local_idx}, accounts_nonces ->
        Model.int_contract_call(tx: aetx) =
          call = State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

        {:oracle_query_tx, tx} = :aetx.specialize_type(aetx)
        sender_pk = :aeo_query_tx.sender_pubkey(tx)
        prev_query_id = :aeo_query_tx.query_id(tx)

        nonce =
          case Map.fetch(accounts_nonces, sender_pk) do
            {:ok, nonce} -> nonce
            :error -> Db.nonce_at_block(block_hash, sender_pk)
          end

        accounts_nonces = Map.put(accounts_nonces, sender_pk, nonce + 1)

        fixed_tx = put_elem(tx, 2, nonce)

        if prev_query_id == :aeo_query_tx.query_id(fixed_tx) do
          {[], accounts_nonces}
        else
          fixed_aetx = :aetx.update_tx(aetx, fixed_tx)

          {[Model.int_contract_call(call, tx: fixed_aetx)], accounts_nonces}
        end
      end)

    List.flatten(calls)
  end
end
