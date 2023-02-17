defmodule AeMdw.Migrations.AddTemplateEdition do
  @moduledoc """
  Adds template edition to NftTemplateToken.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    write_mutations =
      state
      |> Collection.stream(Model.NftTemplateToken, nil)
      |> Stream.map(&State.fetch!(state, Model.NftTemplateToken, &1))
      |> Stream.filter(&match?({:nft_template_token, _key, _txi, _log_idx}, &1))
      |> Enum.map(&WriteMutation.new(Model.NftTemplateToken, Tuple.append(&1, "1")))

    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end
