defmodule AeMdw.Migrations.ReindexAexnCount do
  @moduledoc """
  Indexes aexn contracts count disconsidering those with meta info error.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.AexnContracts
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    aex9_count =
      state
      |> Collection.stream(
        Model.AexnContract,
        :forward,
        {{:aex9, <<>>}, {:aex9, Util.max_256bit_bin()}},
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.AexnContract, &1))
      |> Stream.filter(fn Model.aexn_contract(meta_info: meta_info) ->
        AexnContracts.valid_meta_info?(meta_info)
      end)
      |> Enum.count()

    aex141_count =
      state
      |> Collection.stream(
        Model.AexnContract,
        :forward,
        {{:aex141, <<>>}, {:aex141, Util.max_256bit_bin()}},
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.AexnContract, &1))
      |> Stream.filter(fn Model.aexn_contract(meta_info: meta_info) ->
        AexnContracts.valid_meta_info?(meta_info)
      end)
      |> Enum.count()

    mutations = [
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.aexn_count_key(:aex9), payload: aex9_count)
      ),
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.aexn_count_key(:aex141), payload: aex141_count)
      )
    ]

    _new_state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
