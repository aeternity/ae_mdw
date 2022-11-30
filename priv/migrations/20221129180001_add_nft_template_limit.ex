defmodule AeMdw.Migrations.AddNftTemplateLimit do
  @moduledoc """
  Add edition limit field to nft templates.
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
      |> Collection.stream(Model.NftTemplate, :forward)
      |> Stream.map(&State.fetch!(state, Model.NftTemplate, &1))
      |> Enum.flat_map(fn {:nft_template, index, txi, log_idx} ->
        [
          WriteMutation.new(
            Model.NftTemplate,
            Model.nft_template(index: index, txi: txi, log_idx: log_idx, limit: nil)
          )
        ]
      end)

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
