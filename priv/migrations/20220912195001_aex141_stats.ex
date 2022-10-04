defmodule AeMdw.Migrations.Aex141Stats do
  @moduledoc """
  Indexes nft stats by collection.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Stats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    token_count_mutations =
      state
      |> Collection.stream(Model.NftTokenOwner, nil)
      |> Enum.group_by(fn {contract_pk, _token_id} -> contract_pk end)
      |> Enum.map(fn {contract_pk, token_list} ->
        m_stat = Model.stat(index: Stats.nfts_count_key(contract_pk), payload: length(token_list))
        WriteMutation.new(Model.Stat, m_stat)
      end)

    owners_count_mutations =
      state
      |> Collection.stream(Model.NftOwnerToken, nil)
      |> Enum.map(fn {contract_pk, owner_pk, _token_id} -> {contract_pk, owner_pk} end)
      |> Enum.uniq()
      |> Enum.group_by(fn {contract_pk, _owner_pk} -> contract_pk end)
      |> Enum.map(fn {contract_pk, owner_list} ->
        m_stat =
          Model.stat(index: Stats.nft_owners_count_key(contract_pk), payload: length(owner_list))

        WriteMutation.new(Model.Stat, m_stat)
      end)

    mutations = token_count_mutations ++ owners_count_mutations
    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
