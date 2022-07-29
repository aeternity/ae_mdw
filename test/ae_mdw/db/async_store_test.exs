defmodule AeMdw.Db.AsyncStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

  require Model

  describe "next/2" do
    test "it returns the next value from same table" do
      store = AsyncStore.instance()

      txi1 = Enum.random(100_000_000..999_999_999)
      txi2 = txi1 + 1

      on_exit(fn ->
        store
        |> Store.delete(Model.Tx, txi1)
        |> Store.delete(Model.Tx, txi2)
        |> Store.delete(Model.Type, {:ga_meta_tx, txi1})
      end)

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
