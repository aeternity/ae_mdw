defmodule AeMdw.Migrations.SortGeneralDexSwapsByCreation do
  @moduledoc """
  Reindex dex swaps by txi index of create_txi.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations_length =
      state
      |> Collection.stream(Model.DexSwapTokens, nil)
      |> Enum.map(fn {create_txi, txi, idx} = key ->
        {
          WriteMutation.new(
            Model.DexSwapTokens,
            Model.dex_swap_tokens(index: {txi, idx, create_txi})
          ),
          key
        }
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn chunk ->
        {mutations, deletion_keys} = Enum.unzip(chunk)

        mutations = [
          DeleteKeysMutation.new(%{Model.DexSwapTokens => deletion_keys}) | mutations
        ]

        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, mutations_length}
  end
end
