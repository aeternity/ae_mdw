defmodule AeMdw.Db.ContractTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Contract
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 5]

  require Model

  describe "logs_write" do
    test "indexes logs without remote call" do
      {height, _mb} = {100_000, 0}
      contract_pk = :crypto.strong_rand_bytes(32)
      evt_hash0 = :crypto.strong_rand_bytes(32)
      evt_hash1 = aexn_event_hash(:transfer)

      args0 = [
        <<1::256>>,
        <<2::256>>,
        <<1_000_000::256>>
      ]

      args1 = [
        <<3::256>>,
        <<4::256>>,
        <<1_000_000::256>>
      ]

      data0 = "data"
      data1 = "remote_transfer_log_data"

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {contract_pk, [evt_hash0 | args0], data0},
          {contract_pk, [evt_hash1 | args1], data1}
        ])

      call_txi = height * 1_000
      create_txi = call_txi - 1

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      m_log0 =
        Model.contract_log(
          index: {create_txi, call_txi, evt_hash0, 0},
          ext_contract: nil,
          args: args0,
          data: data0
        )

      assert {:ok, ^m_log0} =
               State.get(state, Model.ContractLog, {create_txi, call_txi, evt_hash0, 0})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data0, call_txi, create_txi, evt_hash0, 0}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash0, call_txi, create_txi, 0})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 0, create_txi, evt_hash0})

      m_log1 =
        Model.contract_log(
          index: {create_txi, call_txi, evt_hash1, 1},
          ext_contract: nil,
          args: args1,
          data: data1
        )

      assert {:ok, ^m_log1} =
               State.get(state, Model.ContractLog, {create_txi, call_txi, evt_hash1, 1})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data1, call_txi, create_txi, evt_hash1, 1}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash1, call_txi, create_txi, 1})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 1, create_txi, evt_hash1})
    end

    test "indexes log for both parent and remote contracts" do
      {height, _mb} = {100_000, 0}
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk = :crypto.strong_rand_bytes(32)
      evt_hash0 = :crypto.strong_rand_bytes(32)
      evt_hash1 = aexn_event_hash(:transfer)

      args0 = [
        <<1::256>>,
        <<2::256>>,
        <<1_000_000::256>>
      ]

      args1 = [
        <<3::256>>,
        <<4::256>>,
        <<1_000_000::256>>
      ]

      data0 = "data"
      data1 = "remote_transfer_log_data"

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {contract_pk, [evt_hash0 | args0], data0},
          {remote_pk, [evt_hash1 | args1], data1}
        ])

      call_txi = height * 1_000
      create_txi = call_txi - 1
      remote_txi = call_txi - 2

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> State.cache_put(:ct_create_sync_cache, remote_pk, remote_txi)
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      m_log0 =
        Model.contract_log(
          index: {create_txi, call_txi, evt_hash0, 0},
          ext_contract: nil,
          args: args0,
          data: data0
        )

      assert {:ok, ^m_log0} =
               State.get(state, Model.ContractLog, {create_txi, call_txi, evt_hash0, 0})

      refute State.exists?(state, Model.ContractLog, {remote_txi, call_txi, evt_hash0, 0})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data0, call_txi, create_txi, evt_hash0, 0}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash0, call_txi, create_txi, 0})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 0, create_txi, evt_hash0})

      m_log =
        Model.contract_log(
          index: {create_txi, call_txi, evt_hash1, 1},
          ext_contract: remote_pk,
          args: args1,
          data: data1
        )

      m_log_remote =
        Model.contract_log(
          index: {remote_txi, call_txi, evt_hash1, 1},
          ext_contract: {:parent_contract_pk, contract_pk},
          args: args1,
          data: data1
        )

      assert {:ok, ^m_log} =
               State.get(state, Model.ContractLog, {create_txi, call_txi, evt_hash1, 1})

      assert {:ok, ^m_log_remote} =
               State.get(state, Model.ContractLog, {remote_txi, call_txi, evt_hash1, 1})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data1, call_txi, create_txi, evt_hash1, 1}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash1, call_txi, create_txi, 1})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 1, create_txi, evt_hash1})
    end

    test "does not update aex9 event balance on contract creation" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:mint), account_pk1, <<1_000_000::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:burn), account_pk1, <<10::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:swap), account_pk1, <<20::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:transfer), account_pk1, account_pk2, <<30::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
        |> Contract.logs_write(txi, txi, call_rec)

      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk1})
      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk2})

      refute :not_found ==
               State.get(state, Model.AexnTransfer, {:aex9, account_pk1, txi, account_pk2, 30, 3})
    end
  end
end
