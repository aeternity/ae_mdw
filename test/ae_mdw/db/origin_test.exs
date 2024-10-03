defmodule AeMdw.Db.OriginTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Validate

  import Mock

  require Model

  @contract_id1 "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6"
  @contract_id2 "ct_KJgjAXMtRF68AbT5A2aC9fTk8PA4WFv26cFSY27fXs6FtYQHK"

  describe "tx_index/2" do
    test "returns relative index of hardfork contracts" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      with_mocks [
        {:aeu_env, [:passthrough],
         [
           find_config: fn
             ["chain", "hard_forks"], [:user_config] ->
               {:ok, %{"5" => 0}}

             ["sync", "peer_analytics"], [:user_config, :schema_default, {:value, false}] ->
               {:ok, false}
           end
         ]},
        {:aec_fork_block_settings, [],
         [
           lima_contracts: fn ->
             [%{pubkey: Validate.id!(@contract_id1), amount: 2_448_618_414_302_482_322}]
           end,
           contracts: fn
             _protocol -> %{"calls" => [], "contracts" => [%{"pubkey" => @contract_id2}]}
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
