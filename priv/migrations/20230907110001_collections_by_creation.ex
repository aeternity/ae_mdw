defmodule AeMdw.Migrations.CollectionsByCreation do
  # credo:disable-for-this-file
  @moduledoc """
  Index NFT collections by creation.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  @max_name Util.max_name_bin()

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations_aex141 =
      state
      |> Collection.stream(
        Model.AexnContractName,
        :forward,
        {{:aex141, nil, <<>>}, {:aex141, @max_name, <<>>}},
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.AexnContractName, &1))
      |> Stream.map(fn Model.aexn_contract_name(index: {:aex141, _name, contract_pk}) ->
        State.fetch!(state, Model.AexnContract, {:aex141, contract_pk})
      end)
      |> Stream.flat_map(fn {:aexn_contract, {:aex141, contract_pk}, txi, meta_info, extensions} ->
        [
          WriteMutation.new(
            Model.AexnContract,
            Model.aexn_contract(
              index: {:aex141, contract_pk},
              txi_idx: {txi, -1},
              meta_info: meta_info,
              extensions: extensions
            )
          ),
          WriteMutation.new(
            Model.AexnContractCreation,
            Model.aexn_contract_creation(index: {:aex141, {txi, -1}, contract_pk})
          )
        ]
      end)
      |> Enum.to_list()

    mutations_aex9 =
      state
      |> Collection.stream(
        Model.AexnContractName,
        :forward,
        {{:aex9, nil, <<>>}, {:aex9, @max_name, <<>>}},
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.AexnContractName, &1))
      |> Stream.map(fn Model.aexn_contract_name(index: {:aex9, _name, contract_pk}) ->
        State.fetch!(state, Model.AexnContract, {:aex9, contract_pk})
      end)
      |> Stream.map(fn {:aexn_contract, {:aex9, contract_pk}, txi, meta_info, extensions} ->
        WriteMutation.new(
          Model.AexnContract,
          Model.aexn_contract(
            index: {:aex9, contract_pk},
            txi_idx: {txi, -1},
            meta_info: meta_info,
            extensions: extensions
          )
        )
      end)
      |> Enum.to_list()

    mutations = mutations_aex141 ++ mutations_aex9

    _ = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end
end
