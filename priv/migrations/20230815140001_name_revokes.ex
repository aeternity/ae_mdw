defmodule AeMdw.Migrations.NameRevokes do
  # credo:disable-for-this-file
  @moduledoc """
  Index name revokes.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Node

  require Model

  import AeMdw.Util, only: [max_int: 0]

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    tx_mutations =
      state
      |> Collection.stream(
        Model.Type,
        :forward,
        {{:name_revoke, 0}, {:name_revoke_tx, max_int()}},
        nil
      )
      |> Stream.map(fn {:name_revoke_tx, txi} ->
        Model.tx(block_index: {height, _mbi}, id: tx_hash) = State.fetch!(state, Model.Tx, txi)
        {:name_revoke_tx, aetx} = Node.Db.get_tx(tx_hash)
        name_hash = :aens_revoke_tx.name_hash(aetx)
        Model.plain_name(index: plain_name) = State.fetch!(state, Model.PlainName, name_hash)
        m_revoke = Model.name_revoke(index: {plain_name, height, {txi, -1}})

        WriteMutation.new(Model.NameRevoke, m_revoke)
      end)
      |> Enum.to_list()

    calls_mutations =
      state
      |> Collection.stream(
        Model.FnameIntContractCall,
        :forward,
        {{"AENS.revoke", 0, 0}, {"AENS.revoke", max_int(), max_int()}},
        nil
      )
      |> Enum.map(fn {"AENS.revoke", call_txi, local_idx} ->
        Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, call_txi)

        Model.int_contract_call(tx: revoke_aetx) =
          State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

        name_hash = :aens_revoke_tx.name_hash(revoke_aetx)
        Model.plain_name(index: plain_name) = State.fetch!(state, Model.PlainName, name_hash)
        m_revoke = Model.name_revoke(index: {plain_name, height, {call_txi, local_idx}})

        WriteMutation.new(Model.NameRevoke, m_revoke)
      end)
      |> Enum.to_list()

    write_mutations = tx_mutations ++ calls_mutations
    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end
