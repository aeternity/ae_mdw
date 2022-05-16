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

    aexn_mutations =
      Enum.flat_map(aex9_pubkeys, fn contract_pk ->
        {:ok, Model.aex9_contract_pubkey(txi: txi)} =
          Database.fetch(Model.Aex9ContractPubkey, contract_pk)

        {:ok, Model.rev_aex9_contract(index: {txi, name, symbol, decimals})} =
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
      end)

    mutations = [
      DeleteKeysMutation.new(%{Model.Aex9ContractPubkey => aex9_pubkeys})
      | aexn_mutations
    ]

    State.commit(State.new(), mutations)

    indexed_count = length(aex9_pubkeys)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
