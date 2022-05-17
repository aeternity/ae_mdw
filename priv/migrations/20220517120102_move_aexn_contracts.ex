defmodule AeMdw.Migrations.MoveAexnContracts do
  @moduledoc """
  Move AEXN contracts.
  """

  alias AeMdw.Database
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    aex9_pubkeys = Database.all_keys(Model.Aex9ContractPubkey)
    aexn_pubkeys = Database.all_keys(Model.AexNContractPubkey)

    # move old AEX-9 to latest version of AEX-N
    aex9_aexn_mutations = Enum.flat_map(aex9_pubkeys, &new_metainfo_mutations/1)

    # move first version of AEX-N (unreleased) to latest version of AEX-N contracts
    aexn_mutations = Enum.flat_map(aexn_pubkeys, &new_metainfo_mutations/1)

    mutations =
      [
        DeleteKeysMutation.new(%{Model.Aex9ContractPubkey => aex9_pubkeys}),
        DeleteKeysMutation.new(%{Model.AexNContractPubkey => aexn_pubkeys})
      ] ++
        aex9_aexn_mutations ++
        aexn_mutations

    State.commit(State.new(), mutations)

    indexed_count = length(aex9_pubkeys) + length(aexn_pubkeys)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp new_metainfo_mutations(key) do
    {txi, contract_pk} = get_txi_and_pubkey(key)

    {:ok, {txi, name, symbol, decimals}} =
      Database.next_key(Model.RevAex9Contract, {txi, "", "", -1})

    meta_info = {name, symbol, decimals}

    m_aexn =
      Model.aexn_contract(
        index: {:aex9, contract_pk},
        txi: txi,
        meta_info: meta_info
      )

    m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, contract_pk})
    m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, contract_pk})

    [
      WriteMutation.new(Model.AexnContract, m_aexn),
      WriteMutation.new(Model.AexnContractName, m_aexn_name),
      WriteMutation.new(Model.AexnContractSymbol, m_aexn_symbol)
    ]
  end

  defp get_txi_and_pubkey({:aex9, contract_pk} = key) do
    Model.aexn_contract_pubkey(txi: txi) = Database.fetch!(Model.AexNContractPubkey, key)
    {txi, contract_pk}
  end

  defp get_txi_and_pubkey(contract_pk) do
    Model.aex9_contract_pubkey(txi: txi) = Database.fetch!(Model.Aex9ContractPubkey, contract_pk)
    {txi, contract_pk}
  end
end
