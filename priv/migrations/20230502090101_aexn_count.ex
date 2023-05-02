defmodule AeMdw.Migrations.AexnCount do
  @moduledoc """
  Updates totalstats total supply incrementing with the lima contracts amount.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection
  alias AeMdw.Util
  alias AeMdw.Stats

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
      |> Enum.count()

    aex141_count =
      state
      |> Collection.stream(
        Model.AexnContract,
        :forward,
        {{:aex141, <<>>}, {:aex141, Util.max_256bit_bin()}},
        nil
      )
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

    _state = State.commit(state, mutations)

    {:ok, 2}
  end
end
