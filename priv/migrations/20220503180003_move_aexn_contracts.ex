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
      aex9_pubkeys
      |> Enum.map(fn contract_pk ->
        {:ok, Model.aex9_contract_pubkey(txi: txi)} =
          Database.fetch(Model.Aex9ContractPubkey, contract_pk)

        {:ok, Model.rev_aex9_contract(index: {txi, name, symbol, decimals})} =
          Database.next_key(Model.RevAex9Contract, {txi, "", "", -1})

        m_aexn =
          Model.aexn_contract(
            index: {:aex9, contract_pk},
            txi: txi,
            meta_info: {name, symbol, decimals}
          )

        WriteMutation.new(Model.AexnContract, m_aexn)
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
