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
    key_boundary = {{0, <<>>, 0, 0}, {nil, Util.max_256bit_bin(), nil, nil}}

    mutations =
      state
      |> Collection.stream(Model.DexContractSwapTokens, :forward, key_boundary, nil)
      |> Enum.map(fn Model.dex_contract_swap_tokens(index: {create_txi, _from, txi, idx}) ->
        WriteMutation.new(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {create_txi, txi, idx})
        )
      end)

    _state = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end
end
