defmodule AeMdw.Migrations.Aex9toAexnTransfer do
  @moduledoc """
  Converts AEX-9 transfers to AEX-n ones .
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Util

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    state = State.new()
    begin = DateTime.utc_now()

    write_mutations =
      state
      |> Collection.stream(Model.Aex9Transfer, nil)
      |> Stream.flat_map(fn {from_pk, txi, to_pk, amount, i} ->
        Model.tx(id: hash) = Util.read_tx!(state, txi)
        {_block_hash, type, _signed_tx, tx_rec} = AeMdw.Node.Db.get_tx_data(hash)
        contract_pk = get_contract_pk(type, tx_rec)

        m_transfer =
          Model.aexn_transfer(
            index: {:aex9, from_pk, txi, to_pk, amount, i},
            contract_pk: contract_pk
          )

        m_rev_transfer = Model.rev_aexn_transfer(index: {:aex9, to_pk, txi, from_pk, amount, i})
        m_pair_transfer = Model.aexn_pair_transfer(index: {:aex9, from_pk, to_pk, txi, amount, i})

        [
          WriteMutation.new(Model.AexnTransfer, m_transfer),
          WriteMutation.new(Model.RevAexnTransfer, m_rev_transfer),
          WriteMutation.new(Model.AexnPairTransfer, m_pair_transfer)
        ]
      end)
      |> Enum.to_list()

    State.commit_db(state, write_mutations, false)
    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {div(length(write_mutations), 3), duration}}
  end

  defp get_contract_pk(type, tx) do
    case type do
      :contract_call_tx ->
        :aect_call_tx.contract_pubkey(tx)

      :contract_create_tx ->
        :aect_create_tx.contract_pubkey(tx)

      :ga_meta_tx ->
        signed_tx = InnerTx.signed_tx(:ga_meta_tx, tx)
        {mod, tx_rec} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
        get_contract_pk(mod.type(), tx_rec)
    end
  end
end
