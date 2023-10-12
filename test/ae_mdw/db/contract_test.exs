defmodule AeMdw.Db.ContractTest do
  use ExUnit.Case, async: false

  alias AeMdw.Aex9
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 3, call_rec: 5]
  import AeMdw.TestUtil, only: [empty_state: 0]

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
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      m_log0 =
        Model.contract_log(
          index: {create_txi, call_txi, 0},
          ext_contract: nil,
          args: args0,
          data: data0,
          hash: evt_hash0
        )

      assert {:ok, ^m_log0} = State.get(state, Model.ContractLog, {create_txi, call_txi, 0})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data0, call_txi, create_txi, 0}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash0, call_txi, create_txi, 0})
      assert State.exists?(state, Model.CtEvtContractLog, {evt_hash0, create_txi, call_txi, 0})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 0, create_txi})

      m_log1 =
        Model.contract_log(
          index: {create_txi, call_txi, 1},
          ext_contract: nil,
          args: args1,
          data: data1,
          hash: evt_hash1
        )

      assert {:ok, ^m_log1} = State.get(state, Model.ContractLog, {create_txi, call_txi, 1})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data1, call_txi, create_txi, 1}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash1, call_txi, create_txi, 1})
      assert State.exists?(state, Model.CtEvtContractLog, {evt_hash1, create_txi, call_txi, 1})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 1, create_txi})
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
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> State.cache_put(:ct_create_sync_cache, remote_pk, remote_txi)
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      m_log0 =
        Model.contract_log(
          index: {create_txi, call_txi, 0},
          ext_contract: nil,
          args: args0,
          data: data0,
          hash: evt_hash0
        )

      assert {:ok, ^m_log0} = State.get(state, Model.ContractLog, {create_txi, call_txi, 0})

      refute State.exists?(state, Model.ContractLog, {remote_txi, call_txi, 0})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data0, call_txi, create_txi, 0}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash0, call_txi, create_txi, 0})
      assert State.exists?(state, Model.CtEvtContractLog, {evt_hash0, create_txi, call_txi, 0})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 0, create_txi})

      m_log =
        Model.contract_log(
          index: {create_txi, call_txi, 1},
          ext_contract: remote_pk,
          args: args1,
          data: data1,
          hash: evt_hash1
        )

      m_log_remote =
        Model.contract_log(
          index: {remote_txi, call_txi, 1},
          ext_contract: {:parent_contract_pk, contract_pk},
          args: args1,
          data: data1,
          hash: evt_hash1
        )

      assert {:ok, ^m_log} = State.get(state, Model.ContractLog, {create_txi, call_txi, 1})

      assert {:ok, ^m_log_remote} = State.get(state, Model.ContractLog, {remote_txi, call_txi, 1})

      assert State.exists?(
               state,
               Model.DataContractLog,
               {data1, call_txi, create_txi, 1}
             )

      assert State.exists?(state, Model.EvtContractLog, {evt_hash1, call_txi, create_txi, 1})
      assert State.exists?(state, Model.CtEvtContractLog, {evt_hash1, create_txi, call_txi, 1})
      assert State.exists?(state, Model.IdxContractLog, {call_txi, 1, create_txi})
    end

    test "does not update aex9 event balance on contract create transaction" do
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
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {txi, -1})
        )
        |> Contract.logs_write(txi, txi, call_rec)

      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk1})
      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk2})

      refute :not_found ==
               State.get(state, Model.AexnTransfer, {:aex9, account_pk1, txi, account_pk2, 30, 3})
    end

    test "does not update aex9 event balance on contract created by event" do
      contract_pk1 = :crypto.strong_rand_bytes(32)
      contract_pk2 = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      create_txi1 = Enum.random(100_000_000..999_999_999)
      txi = create_txi1 + 1
      create_txi2 = txi

      call_rec =
        call_rec("logs", contract_pk1, height, nil, [
          {
            contract_pk2,
            [aexn_event_hash(:mint), account_pk1, <<2_000_000::256>>],
            ""
          },
          {
            contract_pk2,
            [aexn_event_hash(:transfer), account_pk1, account_pk2, <<1_000_000::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk2, {type_info, nil, nil})

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk1, create_txi1)
        |> State.cache_put(:ct_create_sync_cache, contract_pk2, create_txi2)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk1}, txi_idx: {create_txi1, -1})
        )
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk2}, txi_idx: {create_txi2, -1})
        )
        |> Contract.logs_write(create_txi1, txi, call_rec)

      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk2, account_pk1})
      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk2, account_pk2})

      refute :not_found ==
               State.get(
                 state,
                 Model.AexnTransfer,
                 {:aex9, account_pk1, txi, account_pk2, 1_000_000, 1}
               )
    end

    test "initializes aex9 contract balance and counts logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:mint), account_pk1, <<1_000::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:burn), account_pk1, <<100::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:swap), account_pk1, <<200::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {txi, -1})
        )
        |> Contract.logs_write(txi, txi + 1, call_rec)

      assert Model.aex9_contract_balance(amount: 700) =
               State.fetch!(state, Model.Aex9ContractBalance, contract_pk)

      assert 3 = Stats.fetch_aex9_logs_count(state, contract_pk)
    end

    test "writes mint and transfer balance when adding liquidity" do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk1 = :crypto.strong_rand_bytes(32)
      remote_pk2 = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      mint_amount = 1234
      transfer_amount = 5678

      call_rec =
        call_rec(
          "add_liquidity",
          {remote_pk1, account_pk1, mint_amount},
          {remote_pk2, account_pk2, transfer_amount}
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, remote_pk1, {type_info, nil, nil})
      AeMdw.EtsCache.put(AeMdw.Contract, remote_pk2, {type_info, nil, nil})

      txi = Enum.random(100_000_000..999_999_999)

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi - 2)
        |> State.cache_put(:ct_create_sync_cache, remote_pk1, txi - 1)
        |> State.cache_put(:ct_create_sync_cache, remote_pk2, txi - 1)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {txi - 2, -1})
        )
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, remote_pk1}, txi_idx: {txi - 1, -1})
        )
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, remote_pk2}, txi_idx: {txi - 1, -1})
        )
        |> Contract.logs_write(txi - 1, txi, call_rec)

      assert {:ok, Model.aex9_event_balance(amount: ^mint_amount)} =
               State.get(state, Model.Aex9EventBalance, {remote_pk1, account_pk1})

      assert {:ok, Model.aex9_event_balance(amount: ^transfer_amount)} =
               State.get(state, Model.Aex9EventBalance, {remote_pk2, account_pk2})
    end

    test "does not update the balance when transfer accounts are the same" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:transfer), account_pk1, account_pk2, <<2_000_000::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:transfer), account_pk2, account_pk2, <<3_000_000::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi - 1)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {txi - 1, -1})
        )
        |> Contract.logs_write(txi - 1, txi, call_rec)

      assert {:ok, Model.aex9_event_balance(amount: -2_000_000)} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk1})

      assert {:ok, Model.aex9_event_balance(amount: 2_000_000)} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk2})

      refute :not_found ==
               State.get(
                 state,
                 Model.AexnTransfer,
                 {:aex9, account_pk1, txi, account_pk2, 2_000_000, 0}
               )

      refute :not_found ==
               State.get(
                 state,
                 Model.AexnTransfer,
                 {:aex9, account_pk2, txi, account_pk2, 3_000_000, 1}
               )
    end

    test "updates the balance successfully after multiple operations" do
      contract_pk = :crypto.strong_rand_bytes(32)

      account_pk =
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>

      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)

      call_rec_list =
        transfer_events_fixture()
        |> Enum.map(fn [pk1, pk2, value] ->
          call_rec("logs", contract_pk, height, nil, [
            {contract_pk, [aexn_event_hash(:transfer), pk1, pk2, value], ""}
          ])
        end)

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      create_txi = txi - 1

      state =
        empty_state()
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {create_txi, -1})
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)

      {state, _txi} =
        Enum.reduce(call_rec_list, {state, txi}, fn call_rec, {state, txi} ->
          {Contract.logs_write(state, create_txi, txi, call_rec), txi + 1}
        end)

      assert {:ok, Model.aex9_event_balance(amount: 1_190_000_000_000_000_000)} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk})
    end

    test "ignores aex9 events without matching args" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:mint), account_pk1, <<1_000_000::256>>, <<1_000_000::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:burn), account_pk1, <<10::256>>, <<10::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:swap), account_pk1, <<20::256>>, <<20::256>>],
            ""
          },
          {
            contract_pk,
            [aexn_event_hash(:transfer), account_pk1, account_pk2, <<30::256>>, <<30::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        empty_state()
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {txi, -1})
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
        |> Contract.logs_write(txi, txi, call_rec)

      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk1})
      assert :not_found == State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk2})
    end

    test "ignores aex141 events without matching args" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)
      template_id = Enum.random(100..999)

      logs =
        Enum.map(
          [
            :edition_limit,
            :edition_limit_decrease,
            :template_creation,
            :template_deletion
          ],
          fn event -> {contract_pk, [aexn_event_hash(event), <<1::256>>], ""} end
        )

      logs =
        logs ++
          [
            {
              contract_pk,
              [aexn_event_hash(:token_limit), <<1::256>>, <<2::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:template_limit), <<1::256>>, <<2::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:token_limit_decrease), <<1::256>>, <<2::256>>, <<3::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:template_limit_decrease), <<1::256>>, <<2::256>>, <<3::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:mint), account_pk1, <<1::256>>, <<1::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:template_mint), account_pk1, template_id, <<1::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:burn), account_pk1, <<10::256>>, <<10::256>>],
              ""
            },
            {
              contract_pk,
              [aexn_event_hash(:transfer), account_pk1, account_pk2, <<30::256>>, <<30::256>>],
              ""
            }
          ]

      call_rec = call_rec("logs", contract_pk, height, nil, logs)

      functions =
        AeMdw.Node.aex141_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> Contract.logs_write(txi, txi, call_rec)

      assert :not_found == State.get(state, Model.NftContractLimits, contract_pk)
      assert :none == State.prev(state, Model.NftOwnership, {account_pk1, contract_pk, nil})
      assert :none == State.prev(state, Model.NftOwnership, {account_pk2, contract_pk, nil})
      assert :none == State.prev(state, Model.NftTemplate, {contract_pk, nil})
      assert :none == State.prev(state, Model.NftTemplateToken, {contract_pk, template_id, nil})
    end
  end

  describe "aex9_init_event_balances/4" do
    test "increments balance if contract creation dry run finishes after an event" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      txi = Enum.random(100_000_000..999_999_999)
      create_txi = txi - 1

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:transfer), <<1::256>>, account_pk, <<1_000_000::256>>],
            ""
          }
        ])

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        empty_state()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> State.put(
          Model.AexnContract,
          Model.aexn_contract(index: {:aex9, contract_pk}, txi_idx: {create_txi, -1})
        )
        |> Contract.logs_write(create_txi, txi, call_rec)

      assert {:ok, Model.aex9_event_balance(txi: ^txi, log_idx: 0, amount: 1_000_000)} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk})

      state =
        Contract.aex9_init_event_balances(
          state,
          contract_pk,
          [{<<1::256>>, 4_000_000}, {account_pk, 2_000_000}],
          create_txi
        )

      assert {:ok, Model.aex9_event_balance(txi: ^txi, log_idx: 0, amount: 3_000_000)} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk})

      assert {:ok, Model.aex9_initial_supply(amount: 6_000_000)} =
               State.get(state, Model.Aex9InitialSupply, contract_pk)

      assert Model.aex9_contract_balance(amount: 6_000_000) =
               State.fetch!(state, Model.Aex9ContractBalance, contract_pk)

      assert 2 == Aex9.fetch_holders_count(state, contract_pk)
    end
  end

  # sample from testnet DEX ct_T6MWNrowGVC9dyTDksCBrCCSaeK3hzBMMY5hhMKwvwr8wJvM8
  defp transfer_events_fixture() do
    [
      [
        <<193, 154, 95, 143, 119, 92, 219, 121, 97, 201, 190, 133, 111, 169, 91, 139, 211, 144,
          147, 206, 27, 57, 226, 53, 238, 155, 196, 83, 254, 5, 44, 147>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 41, 162, 36, 26,
          246, 44, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<102, 17, 127, 208, 38, 156, 125, 115, 150, 46, 106, 103, 94, 7, 144, 141, 35, 77, 123,
          1, 48, 29, 142, 240, 175, 217, 22, 146, 219, 118, 54, 207>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<127, 196, 158, 127, 145, 71, 126, 7, 161, 187, 100, 252, 116, 174, 24, 39, 211, 98, 88,
          100, 9, 8, 68, 58, 168, 0, 4, 170, 247, 54, 33, 14>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182,
          179, 167, 100, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182,
          179, 167, 100, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 134, 242,
          111, 193, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 71, 13, 228,
          223, 130, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 177, 162,
          188, 46, 197, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 71, 13, 228,
          223, 130, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
          215, 79, 67, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 41, 208, 105,
          24, 158, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 142, 27, 201,
          191, 4, 0, 0>>
      ],
      [
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 134, 242,
          111, 193, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<24, 162, 218, 77, 164, 20, 19, 187, 228, 13, 85, 146, 160, 162, 174, 24, 246, 143, 223,
          72, 229, 221, 131, 9, 135, 148, 134, 208, 107, 142, 142, 113>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 99, 69, 120,
          93, 138, 0, 0>>
      ],
      [
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61, 71,
          15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 134, 242,
          111, 193, 0, 0>>
      ]
    ]
  end
end
