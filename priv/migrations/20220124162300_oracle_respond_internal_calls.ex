defmodule AeMdw.Migrations.OracleRespondInternalCalls do
  @moduledoc """
  Indexes Oracle.respond internal calls if not indexed already.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.Mnesia
  alias AeMdw.Log

  require Ex2ms
  require Model

  @doc """
  Writes the internal transfers for the oracle response internal calls.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    internal_calls_spec =
      Ex2ms.fun do
        Model.fname_int_contract_call(index: {"Oracle.respond", call_txi, local_idx}) ->
          {call_txi, local_idx}
      end

    mutations =
      Model.FnameIntContractCall
      |> :mnesia.dirty_select(internal_calls_spec)
      |> Enum.flat_map(fn {call_txi, _local_idx} = key ->
        [Model.tx(block_index: {kbi, _mbi} = block_index)] =
          :mnesia.dirty_read(Model.Tx, call_txi)

        [Model.block(hash: block_hash)] = :mnesia.dirty_read(Model.Block, {kbi, -1})
        [Model.int_contract_call(tx: tx)] = :mnesia.dirty_read(Model.IntContractCall, key)
        {:oracle_response_tx, oracle_response_tx} = :aetx.specialize_type(tx)

        oracle_pk = :aeo_response_tx.oracle_pubkey(oracle_response_tx)
        query_id = :aeo_response_tx.query_id(oracle_response_tx)
        o_tree = Oracle.oracle_tree!(block_hash)

        try do
          fee =
            oracle_pk
            |> :aeo_state_tree.get_query(query_id, o_tree)
            |> :aeo_query.fee()

          [
            OracleResponseMutation.new(block_index, call_txi, oracle_pk, fee)
          ]
        rescue
          # TreeId = <<OracleId/binary, QId/binary>>,
          # Serialized = aeu_mtrees:get(TreeId, Tree#oracle_tree.otree)
          # raises error on unexisting tree_id
          error ->
            Log.error(error)
            []
        end
      end)

    Mnesia.transaction(mutations)

    indexed_count = length(mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
