defmodule AeMdw.Migrations.OracleRespondInternalCalls do
  @moduledoc """
  Indexes Oracle.respond internal calls if not indexed already.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Database
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
      |> Database.dirty_select(internal_calls_spec)
      |> Enum.map(fn {call_txi, _local_idx} = key ->
        [Model.tx(block_index: {kbi, _mbi} = block_index)] = Database.read(Model.Tx, call_txi)
        [Model.block(hash: block_hash)] = Database.read(Model.Block, {kbi, -1})
        [Model.int_contract_call(tx: tx)] = Database.dirty_read(Model.IntContractCall, key)
        {:oracle_response_tx, oracle_response_tx} = :aetx.specialize_type(tx)

        Oracle.response_mutation(oracle_response_tx, block_index, block_hash, call_txi)
      end)

    Database.transaction(mutations)

    indexed_count = length(mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
