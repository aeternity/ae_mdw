defmodule AeMdw.Db.ModelTest do
  use ExUnit.Case

  alias AeMdw.Db.Model

  describe "tables/0" do
    test "have mapped records" do
      Model.tables()
      |> Enum.each(fn table ->
        assert atom = Model.record(table)
        assert is_atom(atom)
      end)
    end
  end
end
