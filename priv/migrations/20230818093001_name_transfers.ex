defmodule AeMdw.Migrations.NameTransfers do
  # credo:disable-for-this-file
  @moduledoc """
  Reindex name transfers.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    keys =
      state
      |> Collection.stream(Model.NameTransfer, :forward)
      |> Enum.to_list()

    delete_mutation = DeleteKeysMutation.new(%{Model.NameTransfer => keys})

    write_mutations =
      Enum.map(keys, fn {plain_name, height, {_bi, txi_idx}} ->
        WriteMutation.new(Model.NameTransfer, {plain_name, height, txi_idx})
      end)

    mutations = [delete_mutation | write_mutations]
    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
