defmodule AeMdw.Db.OriginTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.TestSamples, as: TS

  require Model

  describe "count_contracts/1" do
    test "it counts spend_tx, contract_call_tx and ga_attach_tx contract origins" do
      contract_pk1 = TS.contract_pk(0)
      contract_pk2 = TS.contract_pk(1)
      contract_pk3 = TS.contract_pk(2)
      contract_pk4 = TS.contract_pk(3)
      contract_pk5 = TS.contract_pk(4)

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, contract_pk1, 123}))
        |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, contract_pk2, 123}))
        |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, contract_pk3, 123}))
        |> Store.put(Model.Origin, Model.origin(index: {:contract_call_tx, contract_pk4, 123}))
        |> Store.put(Model.Origin, Model.origin(index: {:ga_attach_tx, contract_pk5, 123}))
        |> State.new()

      assert 5 = Origin.count_contracts(state)
    end
  end
end
