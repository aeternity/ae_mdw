defmodule AeMdw.Db.RollbackMutationTest do
  use ExUnit.Case, async: true

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.RollbackMutation
  alias AeMdw.Db.State

  require Model

  test "empties the db but keeps the applied migrations" do
    version = 20_261_120_120_000

    state =
      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.put(Model.DeltaStat, Model.delta_stat(index: 1))
      |> State.put(Model.Tx, Model.tx(index: 0))
      |> State.put(Model.Migrations, Model.migrations(index: version))

    state = RollbackMutation.execute(RollbackMutation.new(), state)

    assert State.height(state) == -1
    refute State.exists?(state, Model.Tx, 0)
    assert State.exists?(state, Model.Migrations, version)
  end
end
