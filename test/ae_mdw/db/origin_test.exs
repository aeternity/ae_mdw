defmodule AeMdw.Db.OriginTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Validate
  alias AeMdw.TestSamples, as: TS

  import Mock

  require Model

  @contract_id1 "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6"
  @contract_id2 "ct_KJgjAXMtRF68AbT5A2aC9fTk8PA4WFv26cFSY27fXs6FtYQHK"

  describe "count_contracts/1" do
    test "it counts spend_tx, contract_call_tx and ga_attach_tx contract origins" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_create_tx, TS.contract_pk(0), 123})
        )
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_create_tx, TS.contract_pk(1), 123})
        )
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_create_tx, TS.contract_pk(2), 123})
        )
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_call_tx, TS.contract_pk(3), 123})
        )
        |> Store.put(Model.Origin, Model.origin(index: {:ga_attach_tx, TS.contract_pk(4), 123}))
        |> State.new()

      with_mocks [
        {:aec_fork_block_settings, [],
         [
           lima_contracts: fn ->
             [%{pubkey: Validate.id!(@contract_id1), amount: 2_448_618_414_302_482_322}]
           end,
           hc_seed_contracts: fn 5, "ae_mainnet" ->
             {:ok, [{"calls", []}, {"contracts", [%{"pubkey" => @contract_id2}]}]}
           end
         ]}
      ] do
        assert(5 = Origin.count_contracts(state))
      end
    end
  end

  describe "tx_index/2" do
    test "returns relative index of hardfork contracts" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      with_mocks [
        {:aec_fork_block_settings, [],
         [
           lima_contracts: fn ->
             [%{pubkey: Validate.id!(@contract_id1), amount: 2_448_618_414_302_482_322}]
           end,
           hc_seed_contracts: fn 5, "ae_mainnet" ->
             {:ok, %{"calls" => [], "contracts" => [%{"pubkey" => @contract_id2}]}}
           end
         ]}
      ] do
        :persistent_term.put({Origin, :hardforks_contracts}, nil)
        assert -1 = Origin.tx_index!(state, {:contract, Validate.id!(@contract_id1)})
        assert -2 = Origin.tx_index!(state, {:contract, Validate.id!(@contract_id2)})
        :persistent_term.put({Origin, :hardforks_contracts}, [])
      end
    end
  end
end
