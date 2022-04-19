defmodule AeMdw.Migrations.CreateAex9ContractsFromLogs do
  @moduledoc """
  Indexes aex9 contracts published on event logs.

  These are the ones that are already indexed as contracts with
  :contract_call_tx origin but does not exist yet into Aex9ContractPubkey.
  """

  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.Aex9CreateContractMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    mutations =
      fetch_aex9_pubkeys_txis()
      |> Enum.map(fn {contract_pk, create_txi} ->
        case Contract.aex9_meta_info(contract_pk) do
          {:ok, aex9_meta_info} ->
            block_index = {_kbi, _mbi} = fetch_txi_bi(create_txi)
            Aex9CreateContractMutation.new(contract_pk, aex9_meta_info, block_index, create_txi)

          :not_found ->
            nil
        end
      end)

    mutations
    |> Enum.reject(&is_nil/1)
    |> Database.commit()

    indexed_count = length(mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp fetch_aex9_pubkeys_txis() do
    Model.Origin
    |> Collection.stream({-1, <<>>, -1})
    |> Stream.filter(fn {type, pubkey, _txi} ->
      type == :contract_call_tx and
        not Database.exists?(Model.Aex9ContractPubkey, pubkey) and
        Contract.is_aex9?(pubkey)
    end)
    |> Enum.map(fn {_type, pk, txi} -> {pk, txi} end)
  end

  defp fetch_txi_bi(create_txi) do
    Model.tx(block_index: block_index) = Util.read_tx!(create_txi)
    block_index
  end
end
