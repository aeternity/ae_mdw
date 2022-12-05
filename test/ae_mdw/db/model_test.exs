defmodule AeMdw.Db.ModelTest do
  use ExUnit.Case

  alias AeMdw.Db.Model

  import AeMdw.TestUtil, only: [change_store: 2]

  describe "column_families" do
    test "have mapped records" do
      Model.column_families()
      |> Enum.each(fn table ->
        assert atom = Model.record(table)
        assert is_atom(atom)
      end)
    end
  end
end
