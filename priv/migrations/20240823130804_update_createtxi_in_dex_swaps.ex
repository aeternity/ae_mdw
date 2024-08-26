defmodule AeMdw.Migrations.UpdateCreatetxiInDexSwaps do
  @moduledoc """
  Reindex dex contract swaps with correct create_txi
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Dex

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations_length =
      state
      |> Collection.stream(Model.DexContractSwapTokens, nil)
      |> Enum.map(fn {create_txi, pk, txi, idx} = key ->
        actual_create_txi = Dex.get_create_txi(state, create_txi, txi, idx)

        {
          WriteMutation.new(
            Model.DexContractSwapTokens,
            Model.dex_contract_swap_tokens(index: {actual_create_txi, pk, txi, idx})
          ),
          key
        }
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn chunk ->
        {mutations, deletion_keys} = Enum.unzip(chunk)

        mutations = [
          DeleteKeysMutation.new(%{Model.DexContractSwapTokens => deletion_keys}) | mutations
        ]

        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, mutations_length}
  end
end
