defmodule AeMdw.Migrations.MoveAccountNamesCountToNewTable do
  @moduledoc """
  Move account names count to a new table.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.AccountNamesCount
    |> RocksDbCF.stream()
    |> Stream.flat_map(fn Model.account_names_count(index: owner_id, count: names_count) ->
      [
        WriteMutation.new(
          Model.AccountCounter,
          Model.account_counter(index: owner_id, names: names_count)
        ),
        DeleteKeysMutation.new(%{Model.AccountNamesCount => [owner_id]})
      ]
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _state = State.commit(state, mutations)

      Enum.count(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end
