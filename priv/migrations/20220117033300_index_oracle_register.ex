defmodule AeMdw.Migrations.IndexOracleRegister do
  @moduledoc """
  Indexes all the Oracle.register calls and creates the corresponding
  ActiveOracle records (unless expired).
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Database
  alias AeMdw.Node, as: AE
  alias AeMdw.Log

  require Model
  require Ex2ms
  require Logger

  @doc """
  Searches for contract calls transactions with calls to Oracle.register. Grabs
  the internal "oracle register" transaction from the micro block events and
  indexes it (only if oracle doesn't exist or if transaction is newer than the
  newest oracle registration).
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_startup?) do
    begin = DateTime.utc_now()

    oracle_register_mspec =
      Ex2ms.fun do
        Model.fname_int_contract_call(index: {"Oracle.register", call_txi, _local_idx}) ->
          call_txi
      end

    mutations =
      Model.FnameIntContractCall
      |> Database.dirty_select(oracle_register_mspec)
      |> Enum.map(fn call_txi ->
        [Model.tx(block_index: {kbi, mbi} = block_index, id: tx_hash)] =
          Database.dirty_read(Model.Tx, call_txi)

        # Model.block(hash: block_hash) = Database.dirty_read(Model.Block, {kbi, -1})
        {_key_block, micro_blocks} = AE.Db.get_blocks(kbi)

        {{:internal_call_tx, "Oracle.register"}, %{info: aetx}} =
          micro_blocks
          |> Enum.at(mbi)
          |> AeMdw.Contract.get_grouped_events()
          |> Map.fetch!(tx_hash)
          |> Enum.find(&match?({{:internal_call_tx, "Oracle.register"}, _info}, &1))

        {:oracle_register_tx, tx} = :aetx.specialize_type(aetx)
        oracle_pk = :aeo_register_tx.account_pubkey(tx)
        delta_ttl = :aeo_utils.ttl_delta(kbi, :aeo_register_tx.oracle_ttl(tx))
        expire = kbi + delta_ttl

        case Oracle.locate(oracle_pk) do
          {Model.oracle(register: register), _source} when register < block_index ->
            OracleRegisterMutation.new(oracle_pk, block_index, expire, call_txi)

          {_previous, _source} ->
            nil

          nil ->
            OracleRegisterMutation.new(oracle_pk, block_index, expire, call_txi)
        end
      end)
      |> Enum.reject(&is_nil/1)

    Database.transaction(mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    indexed_count = length(mutations)

    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
