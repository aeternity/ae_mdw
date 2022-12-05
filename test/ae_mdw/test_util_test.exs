defmodule AeMdw.TestUtilTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.NullStore

  import AeMdw.TestUtil, only: [change_store: 2]

  require Model

  describe "change_store" do
    test "raises exception when model table is not declared" do
      assert_raise ArgumentError, fn ->
        NullStore.new()
        |> MemStore.new()
        |> change_store([WriteMutation.new(Model.UnknownTable, Model.name(index: "foo"))])
      end
    end
  end
end
