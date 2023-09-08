defmodule AeMdw.Migrations.CollectionsByCreation do
  # credo:disable-for-this-file
  @moduledoc """
  Index aexn contracts by creation.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(Model.AexnContractName, nil)
      |> Stream.map(&State.fetch!(state, Model.AexnContractName, &1))
      |> Stream.map(fn Model.aexn_contract_name(index: {aexn_type, _name, contract_pk}) ->
        State.fetch!(state, Model.AexnContract, {aexn_type, contract_pk})
      end)
      |> Stream.flat_map(fn {:aexn_contract, {aexn_type, contract_pk}, txi, meta_info, extensions} ->
        [
          WriteMutation.new(
            Model.AexnContract,
            Model.aexn_contract(
              index: {aexn_type, contract_pk},
              txi_idx: {txi, -1},
              meta_info: meta_info,
              extensions: extensions
            )
          ),
          WriteMutation.new(
            Model.AexnContractCreation,
            Model.aexn_contract_creation(index: {aexn_type, {txi, -1}}, contract_pk: contract_pk)
          )
        ]
      end)
      |> Enum.to_list()

    _state = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end
end
