defmodule AeMdw.Db.AsyncStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

  require Model

  describe "next/2" do
    test "it returns the next value from same table" do
      table = :it_returns_the_next_value_from_same_table
      AsyncStore.init(table)
      store = AsyncStore.instance(table)

      txi1 = Enum.random(100_000_000..999_999_999)
      txi2 = txi1 + 1

      store =
        store
        |> Store.put(Model.Tx, Model.tx(index: txi1))
        |> Store.put(Model.Tx, Model.tx(index: txi2))
        |> Store.put(Model.Type, Model.type(index: {:ga_meta_tx, txi1}))

      assert {:ok, ^txi1} = Store.next(store, Model.Tx, txi1 - 1)
      assert {:ok, ^txi2} = Store.next(store, Model.Tx, txi1)
      assert :none = Store.next(store, Model.Tx, 999_999_999)
    end
  end
end
