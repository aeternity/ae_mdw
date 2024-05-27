defmodule AeMdw.Migrations.DexNewSwapsTable do
  # credo:disable-for-this-file
  @moduledoc """
  Index dex events.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations_length =
      state
      |> Collection.stream(Model.DexContractSwapTokens, nil)
      |> Enum.map(fn {create_txi, _from, txi, idx} ->
        WriteMutation.new(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {create_txi, txi, idx})
        )
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, mutations_length}
  end
end
