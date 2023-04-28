defmodule AeMdw.Db.ContractCallMutationTest do
  use AeMdw.Db.MutationCase, async: false

  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Stats
  alias AeMdw.Validate

  import AeMdw.Node.ContractCallFixtures
  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Util.Encoding, only: [encode_account: 1]

  require Model

  @burn_caller_pk <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203,
                    201, 104, 124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>

  describe "aex9 presence" do
    test "add aex9 presence after a mint", %{store: store} do
      contract_pk =
        <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
          108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>

      call_txi = 1_000_001

      assert {account_pk, mutation} = contract_call_mutation("mint", call_txi, contract_pk)

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      store =
        store
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.aex9_account_presence(index: {^account_pk, ^contract_pk}, txi: ^call_txi)} =
               Store.get(store, Model.Aex9AccountPresence, {account_pk, contract_pk})
    end

    test "add aex9 presence after a transfer", %{store: store} do
      contract_pk =
        <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
          108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>

      call_txi = 1_000_002

      assert {account_pk, mutation} = contract_call_mutation("transfer", call_txi, contract_pk)

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      store =
        store
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.aex9_account_presence(index: {^account_pk, ^contract_pk}, txi: ^call_txi)} =
               Store.get(store, Model.Aex9AccountPresence, {account_pk, contract_pk})
    end

    test "add aex9 presence after a burn (balance is 0)", %{store: store} do
      contract_pk =
        <<99, 147, 221, 52, 149, 77, 197, 100, 5, 160, 112, 15, 89, 26, 213, 27, 12, 179, 74, 142,
          40, 64, 84, 157, 179, 9, 194, 215, 194, 131, 3, 108>>

      call_txi = 1_000_003

      assert {account_pk, mutation} = contract_call_mutation("burn", call_txi, contract_pk)

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      store =
        store
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.aex9_account_presence(index: {^account_pk, ^contract_pk}, txi: ^call_txi)} =
               Store.get(store, Model.Aex9AccountPresence, {account_pk, contract_pk})
    end
  end

  describe "aex9 mint" do
    test "increment aex9 balance after a call with mint log", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(account_pk)
          },
          %{
            type: :int,
            value: amount
          }
        ],
        function: "other_mint",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            remote_pk,
            [aexn_event_hash(:mint), account_pk, <<amount::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, remote_pk, {type_info, nil, nil})

      previous_balance = 100_000

      m_balance =
        Model.aex9_event_balance(
          index: {remote_pk, account_pk},
          txi: call_txi - 1,
          log_idx: -1,
          amount: previous_balance
        )

      m_balance_acc =
        Model.aex9_balance_account(
          index: {remote_pk, previous_balance, account_pk},
          txi: call_txi - 1
        )

      assert :not_found = Store.get(store, Model.Stat, Stats.aex9_holder_count_key(remote_pk))

      store =
        store
        |> Store.put(Model.Aex9EventBalance, m_balance)
        |> Store.put(Model.Aex9BalanceAccount, m_balance_acc)
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, remote_pk, call_txi - 2})
        )
        |> change_store([mutation])

      new_amount = previous_balance + amount

      m_new_balance =
        Model.aex9_event_balance(m_balance,
          txi: call_txi,
          log_idx: 0,
          amount: new_amount
        )

      m_new_balance_acc =
        Model.aex9_balance_account(
          index: {remote_pk, new_amount, account_pk},
          txi: call_txi,
          log_idx: 0
        )

      assert {:ok, ^m_new_balance} =
               Store.get(store, Model.Aex9EventBalance, {remote_pk, account_pk})

      assert {:ok, ^m_new_balance_acc} =
               Store.get(store, Model.Aex9BalanceAccount, {remote_pk, new_amount, account_pk})

      assert :not_found =
               Store.get(
                 store,
                 Model.Aex9BalanceAccount,
                 {remote_pk, previous_balance, account_pk}
               )

      assert 1 = Stats.fetch_aex9_holders_count(State.new(store), remote_pk)
    end
  end

  describe "aex9 burn" do
    test "decrement aex9 balance after a call with burn log", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(account_pk)
          },
          %{
            type: :int,
            value: amount
          }
        ],
        function: "other_burn",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:burn), account_pk, <<amount::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      previous_balance = amount + 100_000

      m_balance =
        Model.aex9_event_balance(
          index: {contract_pk, account_pk},
          txi: call_txi - 1,
          log_idx: -1,
          amount: previous_balance
        )

      m_balance_acc =
        Model.aex9_balance_account(
          index: {contract_pk, previous_balance, account_pk},
          txi: call_txi - 1
        )

      store =
        store
        |> Store.put(Model.Aex9EventBalance, m_balance)
        |> Store.put(Model.Aex9BalanceAccount, m_balance_acc)
        |> Store.put(
          Model.Stat,
          Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: 1)
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      m_new_balance =
        Model.aex9_event_balance(m_balance,
          txi: call_txi,
          log_idx: 0,
          amount: 100_000
        )

      m_new_balance_acc =
        Model.aex9_balance_account(
          index: {contract_pk, 100_000, account_pk},
          txi: call_txi,
          log_idx: 0
        )

      assert {:ok, ^m_new_balance} =
               Store.get(store, Model.Aex9EventBalance, {contract_pk, account_pk})

      assert {:ok, ^m_new_balance_acc} =
               Store.get(store, Model.Aex9BalanceAccount, {contract_pk, 100_000, account_pk})

      assert :not_found =
               Store.get(
                 store,
                 Model.Aex9BalanceAccount,
                 {contract_pk, previous_balance, account_pk}
               )

      assert 1 = Stats.fetch_aex9_holders_count(State.new(store), contract_pk)
    end

    test "decrement aex9 holder count after a call with full burn log", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(account_pk)
          },
          %{
            type: :int,
            value: amount
          }
        ],
        function: "other_burn",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:burn), account_pk, <<amount::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      m_balance =
        Model.aex9_event_balance(
          index: {contract_pk, account_pk},
          txi: call_txi - 1,
          log_idx: -1,
          amount: amount
        )

      store =
        store
        |> Store.put(Model.Aex9EventBalance, m_balance)
        |> Store.put(
          Model.Stat,
          Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: 1)
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      m_new_balance =
        Model.aex9_event_balance(m_balance,
          txi: call_txi,
          log_idx: 0,
          amount: 0
        )

      assert {:ok, ^m_new_balance} =
               Store.get(store, Model.Aex9EventBalance, {contract_pk, account_pk})

      assert 0 = Stats.fetch_aex9_holders_count(State.new(store), contract_pk)
    end
  end

  describe "aex9 swap" do
    test "decrement aex9 balance after a call with burn log" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(account_pk)
          },
          %{
            type: :int,
            value: amount
          }
        ],
        function: "other_swap",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:swap), account_pk, <<amount::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      m_balance =
        Model.aex9_event_balance(
          index: {contract_pk, account_pk},
          txi: call_txi - 1,
          log_idx: -1,
          amount: amount + 100_000
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.Aex9EventBalance, m_balance)
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.commit_mem([mutation])

      m_new_balance =
        Model.aex9_event_balance(m_balance,
          txi: call_txi,
          log_idx: 0,
          amount: 100_000
        )

      assert {:ok, ^m_new_balance} =
               State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk})
    end
  end

  describe "aex9 transfer" do
    test "puts aex9 transfers after a call with transfer log" do
      contract_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      from_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{
            type: :int,
            value: 0
          }
        ],
        function: "transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:transfer), from_pk, to_pk, <<amount::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.commit_mem([mutation])

      assert State.exists?(
               state,
               Model.AexnTransfer,
               {:aex9, from_pk, call_txi, to_pk, amount, 0}
             )

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex9, to_pk, call_txi, from_pk, amount, 0}
             )
    end

    test "puts multiple aex9 transfers after a call with transfer logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk1 = :crypto.strong_rand_bytes(32)
      remote_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(100_000_000..999_999_999)

      from_pk1 = <<11::256>>
      to_pk1 = <<12::256>>

      from_pk2 = <<13::256>>
      to_pk2 = <<14::256>>

      amount1 = Enum.random(100_000_000..999_999_999)
      amount2 = Enum.random(100_000_000..999_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :string,
            value: "any"
          },
          %{
            type: :int,
            value: 0
          }
        ],
        function: "multi_transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            remote_pk1,
            [aexn_event_hash(:transfer), from_pk1, to_pk1, <<amount1::256>>],
            ""
          },
          {
            remote_pk2,
            [aexn_event_hash(:transfer), from_pk2, to_pk2, <<amount2::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, remote_pk1, {type_info, nil, nil})
      AeMdw.EtsCache.put(AeMdw.Contract, remote_pk2, {type_info, nil, nil})

      from_amount1 = amount1 + 1

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(
          Model.Aex9EventBalance,
          Model.aex9_event_balance(index: {remote_pk1, from_pk1}, amount: from_amount1)
        )
        |> State.put(
          Model.Aex9BalanceAccount,
          Model.aex9_balance_account(index: {remote_pk1, from_amount1, from_pk1})
        )
        |> State.put(
          Model.Aex9EventBalance,
          Model.aex9_event_balance(index: {remote_pk2, from_pk2}, amount: amount2)
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.cache_put(:ct_create_sync_cache, remote_pk1, call_txi - 2)
        |> State.cache_put(:ct_create_sync_cache, remote_pk2, call_txi - 3)
        |> State.commit_mem([mutation])

      assert 1 = Stats.fetch_aex9_holders_count(state, remote_pk1)
      assert 0 = Stats.fetch_aex9_holders_count(state, remote_pk2)

      new_amount1 = from_amount1 - amount1

      m_bal_acc =
        Model.aex9_balance_account(
          index: {remote_pk1, new_amount1, from_pk1},
          txi: call_txi,
          log_idx: 0
        )

      assert {:ok, ^m_bal_acc} =
               State.get(state, Model.Aex9BalanceAccount, {remote_pk1, new_amount1, from_pk1})

      refute State.exists?(state, Model.Aex9BalanceAccount, {remote_pk1, from_amount1, from_pk1})

      assert State.exists?(
               state,
               Model.AexnTransfer,
               {:aex9, from_pk1, call_txi, to_pk1, amount1, 0}
             )

      assert State.exists?(
               state,
               Model.AexnTransfer,
               {:aex9, from_pk2, call_txi, to_pk2, amount2, 1}
             )

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex9, to_pk1, call_txi, from_pk1, amount1, 0}
             )

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex9, to_pk2, call_txi, from_pk2, amount2, 1}
             )
    end
  end

  describe "aex141 mint" do
    test "add nft ownership after a call with mint logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      token_id = Enum.random(1..100_000)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :int, value: token_id}
        ],
        function: "mint",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        :aect_call.new(
          :aeser_id.create(:account, :crypto.strong_rand_bytes(32)),
          1,
          :aeser_id.create(:contract, contract_pk),
          height,
          1_000_000_000
        )

      call_rec =
        :aect_call.set_log(
          [
            {remote_pk, [aexn_event_hash(:mint), to_pk, <<token_id::256>>], ""}
          ],
          call_rec
        )

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, remote_pk}))
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.cache_put(:ct_create_sync_cache, remote_pk, call_txi - 2)
        |> State.commit_mem([mutation])

      assert State.exists?(state, Model.NftOwnership, {to_pk, remote_pk, token_id})

      assert {:ok, Model.nft_token_owner(owner: ^to_pk)} =
               State.get(state, Model.NftTokenOwner, {remote_pk, token_id})

      assert State.exists?(state, Model.NftOwnerToken, {remote_pk, to_pk, token_id})
    end
  end

  describe "aex141 template mint" do
    test "add nft ownership and supply after a call with the event" do
      contract_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      template_id = Enum.random(1..100)
      token_id = Enum.random(1..100_000)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :int, value: template_id},
          %{type: :int, value: token_id}
        ],
        function: "some_template_mint",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              aexn_event_hash(:template_mint),
              to_pk,
              <<template_id::256>>,
              <<token_id::256>>,
              "1"
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      m_nft_template =
        Model.nft_template(
          index: {contract_pk, template_id},
          txi: call_txi - 2,
          log_idx: 1
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> State.put(Model.NftTemplate, m_nft_template)
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.commit_mem([mutation])

      assert {:ok, Model.nft_ownership(template_id: ^template_id)} =
               State.get(state, Model.NftOwnership, {to_pk, contract_pk, token_id})

      assert {:ok, Model.nft_token_owner(owner: ^to_pk)} =
               State.get(state, Model.NftTokenOwner, {contract_pk, token_id})

      assert State.exists?(state, Model.NftOwnerToken, {contract_pk, to_pk, token_id})

      assert {:ok, ^m_nft_template} =
               State.get(state, Model.NftTemplate, {contract_pk, template_id})

      assert {:ok, Model.nft_token_template(template: ^template_id)} =
               State.get(state, Model.NftTokenTemplate, {contract_pk, token_id})

      assert {:ok, Model.nft_template_token(txi: ^call_txi, log_idx: 0, edition: "1")} =
               State.get(state, Model.NftTemplateToken, {contract_pk, template_id, token_id})

      assert {:ok, Model.stat(payload: 1)} =
               State.get(
                 state,
                 Model.Stat,
                 Stats.nft_template_tokens_key(contract_pk, template_id)
               )
    end
  end

  describe "aex141 template creation" do
    test "writes nft template after a call with the event", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      template_id = Enum.random(1..100)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :string, value: "ipfs://some-hash"}
        ],
        function: "some_template_create",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              <<12_345::256>>,
              <<template_id::256>>
            ],
            ""
          },
          {
            contract_pk,
            [
              aexn_event_hash(:template_creation),
              <<template_id::256>>
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      store =
        store
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok, Model.nft_template(txi: ^call_txi, log_idx: 1)} =
               Store.get(store, Model.NftTemplate, {contract_pk, template_id})
    end

    test "updates nft template with edition limit", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      template_id = Enum.random(1..1_000)
      limit = Enum.random(1..1_000)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :string, value: "ipfs://some-hash"}
        ],
        function: "some_template_create",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              <<12_345::256>>,
              <<template_id::256>>
            ],
            ""
          },
          {
            contract_pk,
            [
              aexn_event_hash(:template_creation),
              <<template_id::256>>
            ],
            ""
          },
          {
            contract_pk,
            [
              aexn_event_hash(:edition_limit),
              <<template_id::256>>,
              <<limit::256>>
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      store =
        store
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok, Model.nft_template(txi: ^call_txi, log_idx: 1, limit: {^limit, ^call_txi, 2})} =
               Store.get(store, Model.NftTemplate, {contract_pk, template_id})
    end

    test "decreases nft template edition limit", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      template_id = Enum.random(1..1_000)
      limit = Enum.random(1..1_000)

      fun_arg_res = %{
        arguments: [
          %{type: :integer, value: template_id},
          %{type: :integer, value: limit}
        ],
        function: "edition_decrease",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              aexn_event_hash(:edition_limit_decrease),
              <<template_id::256>>,
              <<limit + 1::256>>,
              <<limit::256>>
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      template_txi = call_txi - 1

      store =
        store
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> Store.put(
          Model.NftTemplate,
          Model.nft_template(index: {contract_pk, template_id}, txi: template_txi, log_idx: 1)
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 2})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.nft_template(txi: ^template_txi, log_idx: 1, limit: {^limit, ^call_txi, 0})} =
               Store.get(store, Model.NftTemplate, {contract_pk, template_id})
    end
  end

  describe "aex141 template deletion" do
    test "deletes nft template after a call with the event" do
      contract_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      template_id = Enum.random(1..100)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :string, value: "ipfs://some-hash"}
        ],
        function: "some_template_create",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              <<12_345::256>>,
              <<template_id::256>>
            ],
            ""
          },
          {
            contract_pk,
            [
              aexn_event_hash(:template_deletion),
              <<template_id::256>>
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> State.put(
          Model.NftTemplate,
          Model.nft_template(index: {contract_pk, template_id}, txi: call_txi, log_idx: 0)
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.commit_mem([mutation])

      assert :not_found = State.get(state, Model.NftTemplate, {contract_pk, template_id})
    end
  end

  describe "aex141 token limit" do
    test "writes nft token limit after a call with the event", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk1 = :crypto.strong_rand_bytes(32)
      remote_pk2 = :crypto.strong_rand_bytes(32)
      limit1 = Enum.random(1_000..9_999)
      limit2 = Enum.random(1_000..9_999)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)

      fun_arg_res = %{
        arguments: [
          %{type: :integer, value: 1}
        ],
        function: "some_change_token_limit",
        result: %{type: :unit, value: ""}
      }

      valid_events = [
        {
          remote_pk1,
          [
            aexn_event_hash(:token_limit),
            <<limit1::256>>
          ],
          ""
        },
        {
          remote_pk2,
          [
            aexn_event_hash(:token_limit_decrease),
            <<limit2 + 1::256>>,
            <<limit2::256>>
          ],
          ""
        }
      ]

      invalid_events = [
        {
          remote_pk1,
          [
            aexn_event_hash(:token_limit),
            <<limit1 + 1::256>>,
            <<limit1::256>>
          ],
          ""
        },
        {
          remote_pk2,
          [
            aexn_event_hash(:token_limit_decrease),
            <<limit2::256>>
          ],
          ""
        }
      ]

      call_rec = call_rec("logs", contract_pk, height, nil, valid_events ++ invalid_events)

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      store =
        store
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, remote_pk1}))
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, remote_pk2}))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, remote_pk1, call_txi - 2})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, remote_pk2, call_txi - 3})
        )
        |> change_store([mutation])

      assert {:ok, Model.nft_contract_limits(token_limit: ^limit1, txi: ^call_txi, log_idx: 0)} =
               Store.get(store, Model.NftContractLimits, remote_pk1)

      assert {:ok, Model.nft_contract_limits(token_limit: ^limit2, txi: ^call_txi, log_idx: 1)} =
               Store.get(store, Model.NftContractLimits, remote_pk2)
    end
  end

  describe "aex141 template limit" do
    test "decreases template limit after a call with the event", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      old_limit = Enum.random(1_000..9_999)
      new_limit = old_limit - 1
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)

      fun_arg_res = %{
        arguments: [
          %{type: :integer, value: 1}
        ],
        function: "some_template_limit_decrease",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [
              aexn_event_hash(:template_limit_decrease),
              <<old_limit::256>>,
              <<new_limit::256>>
            ],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      store =
        store
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.nft_contract_limits(template_limit: ^new_limit, txi: ^call_txi, log_idx: 0)} =
               Store.get(store, Model.NftContractLimits, contract_pk)
    end
  end

  describe "aex141 transfer" do
    test "puts aex141 transfers records after a call with transfer log" do
      contract_pk = :crypto.strong_rand_bytes(32)
      from_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      token_id = Enum.random(1..100_000)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: encode_account(from_pk)
          },
          %{
            type: :address,
            value: encode_account(to_pk)
          },
          %{type: :int, value: token_id}
        ],
        function: "transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            contract_pk,
            [aexn_event_hash(:transfer), from_pk, to_pk, <<token_id::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> put_existing_nft(contract_pk, from_pk, token_id)
        |> put_stats(contract_pk, 1, 1)
        |> State.commit_mem([mutation])

      assert State.exists?(state, Model.NftOwnership, {to_pk, contract_pk, token_id})

      assert {:ok, Model.nft_token_owner(owner: ^to_pk)} =
               State.get(state, Model.NftTokenOwner, {contract_pk, token_id})

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nfts_count_key(contract_pk))

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nft_owners_count_key(contract_pk))

      assert State.exists?(state, Model.NftOwnerToken, {contract_pk, to_pk, token_id})
      refute State.exists?(state, Model.NftOwnership, {from_pk, contract_pk, token_id})
      refute State.exists?(state, Model.NftOwnerToken, {contract_pk, from_pk, token_id})

      key = {:aex141, from_pk, call_txi, to_pk, token_id, 0}

      assert Model.aexn_transfer(index: ^key, contract_pk: ^contract_pk) =
               State.fetch!(state, Model.AexnTransfer, key)

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex141, to_pk, call_txi, from_pk, token_id, 0}
             )

      assert State.exists?(
               state,
               Model.AexnPairTransfer,
               {:aex141, from_pk, to_pk, call_txi, token_id, 0}
             )
    end

    test "puts multiple aex141 transfers after a call with transfer logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk1 = :crypto.strong_rand_bytes(32)
      remote_pk2 = :crypto.strong_rand_bytes(32)
      from_pk1 = <<11::256>>
      to_pk1 = <<12::256>>
      from_pk2 = <<13::256>>
      to_pk2 = <<14::256>>
      token_id1 = Enum.random(1..100_000)
      token_id2 = Enum.random(1..100_000)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)

      fun_arg_res = %{
        arguments: [
          %{
            type: :string,
            value: "any1"
          }
        ],
        function: "multi_transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {
            remote_pk1,
            [aexn_event_hash(:transfer), from_pk1, to_pk1, <<token_id1::256>>],
            ""
          },
          {
            remote_pk2,
            [aexn_event_hash(:transfer), from_pk2, to_pk2, <<token_id2::256>>],
            ""
          }
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, remote_pk1}))
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, remote_pk2}))
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.cache_put(:ct_create_sync_cache, remote_pk1, call_txi - 2)
        |> State.cache_put(:ct_create_sync_cache, remote_pk2, call_txi - 3)
        |> put_existing_nft(remote_pk1, from_pk1, token_id1)
        |> put_existing_nft(remote_pk2, from_pk2, token_id2)
        |> put_stats(remote_pk1, 1, 1)
        |> put_stats(remote_pk2, 1, 1)
        |> State.commit_mem([mutation])

      assert State.exists?(state, Model.NftOwnership, {to_pk1, remote_pk1, token_id1})
      assert State.exists?(state, Model.NftOwnership, {to_pk2, remote_pk2, token_id2})

      assert {:ok, Model.nft_token_owner(owner: ^to_pk1)} =
               State.get(state, Model.NftTokenOwner, {remote_pk1, token_id1})

      assert {:ok, Model.nft_token_owner(owner: ^to_pk2)} =
               State.get(state, Model.NftTokenOwner, {remote_pk2, token_id2})

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nfts_count_key(remote_pk1))

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nft_owners_count_key(remote_pk1))

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nfts_count_key(remote_pk2))

      assert {:ok, Model.stat(payload: 1)} =
               State.get(state, Model.Stat, Stats.nft_owners_count_key(remote_pk2))

      assert State.exists?(state, Model.NftOwnerToken, {remote_pk1, to_pk1, token_id1})
      refute State.exists?(state, Model.NftOwnership, {from_pk1, remote_pk1, token_id1})
      refute State.exists?(state, Model.NftOwnerToken, {remote_pk1, from_pk1, token_id1})

      assert State.exists?(state, Model.NftOwnerToken, {remote_pk2, to_pk2, token_id2})
      refute State.exists?(state, Model.NftOwnership, {from_pk2, remote_pk2, token_id2})
      refute State.exists?(state, Model.NftOwnerToken, {remote_pk2, from_pk2, token_id2})

      key1 = {:aex141, from_pk1, call_txi, to_pk1, token_id1, 0}
      key2 = {:aex141, from_pk2, call_txi, to_pk2, token_id2, 1}

      assert Model.aexn_transfer(index: ^key1, contract_pk: ^remote_pk1) =
               State.fetch!(state, Model.AexnTransfer, key1)

      assert Model.aexn_transfer(index: ^key2, contract_pk: ^remote_pk2) =
               State.fetch!(state, Model.AexnTransfer, key2)

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex141, to_pk1, call_txi, from_pk1, token_id1, 0}
             )

      assert State.exists?(
               state,
               Model.RevAexnTransfer,
               {:aex141, to_pk2, call_txi, from_pk2, token_id2, 1}
             )

      assert State.exists?(
               state,
               Model.AexnPairTransfer,
               {:aex141, from_pk1, to_pk1, call_txi, token_id1, 0}
             )

      assert State.exists?(
               state,
               Model.AexnPairTransfer,
               {:aex141, from_pk2, to_pk2, call_txi, token_id2, 1}
             )
    end
  end

  describe "aex141 burn" do
    test "remove nft ownership and supply after a call with burn log" do
      contract_pk = <<11::256>>
      owner_pk = <<12::256>>
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      token_id1 = Enum.random(1..100_000)
      token_id2 = Enum.random(1..100_000)

      fun_arg_res = %{
        arguments: [
          %{type: :int, value: token_id1}
        ],
        function: "burn",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        call_rec("logs", contract_pk, height, nil, [
          {contract_pk, [aexn_event_hash(:burn), owner_pk, <<token_id1::256>>], ""}
        ])

      mutation =
        ContractCallMutation.new(
          contract_pk,
          call_txi,
          fun_arg_res,
          call_rec
        )

      template_id = 1

      m_nft_template =
        Model.nft_template(
          index: {contract_pk, template_id},
          txi: call_txi - 2,
          log_idx: 1
        )

      nft_template_tokens_key = Stats.nft_template_tokens_key(contract_pk, template_id)

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.put(
          Model.NftTokenTemplate,
          Model.nft_token_template(index: {contract_pk, token_id1}, template: template_id)
        )
        |> State.put(
          Model.NftTemplateToken,
          Model.nft_template_token(
            index: {contract_pk, template_id, token_id1},
            txi: call_txi - 1,
            log_idx: 1
          )
        )
        |> State.put(Model.Stat, Model.stat(index: nft_template_tokens_key, payload: 1))
        |> State.put(Model.NftTemplate, m_nft_template)
        |> put_existing_nft(contract_pk, owner_pk, token_id1)
        |> put_existing_nft(contract_pk, owner_pk, token_id2)
        |> put_stats(contract_pk, 2, 1)
        |> State.commit_mem([mutation])

      refute State.exists?(state, Model.NftOwnership, {owner_pk, contract_pk, token_id1})
      assert State.exists?(state, Model.NftOwnership, {owner_pk, contract_pk, token_id2})

      refute State.exists?(state, Model.NftTokenOwner, {contract_pk, token_id1})

      assert {:ok, Model.nft_token_owner(owner: ^owner_pk)} =
               State.get(state, Model.NftTokenOwner, {contract_pk, token_id2})

      refute State.exists?(state, Model.NftOwnerToken, {contract_pk, owner_pk, token_id1})
      assert State.exists?(state, Model.NftOwnerToken, {contract_pk, owner_pk, token_id2})

      assert {:ok, ^m_nft_template} =
               State.get(state, Model.NftTemplate, {contract_pk, template_id})

      refute State.exists?(state, Model.NftTokenTemplate, {contract_pk, token_id1})
      refute State.exists?(state, Model.NftTemplateToken, {contract_pk, template_id, token_id1})
      assert {:ok, Model.stat(payload: 0)} = State.get(state, Model.Stat, nft_template_tokens_key)
    end
  end

  defp contract_call_mutation(fname, call_txi, contract_pk) do
    %{arguments: args} = fun_arg_res = fun_args_res(fname)
    call_rec = call_rec(fname)

    account_pk =
      if fname in ["burn"] do
        @burn_caller_pk
      else
        case args do
          [%{type: :address, value: account_id}, _int_val] ->
            Validate.id!(account_id)

          [%{type: :address}, %{type: :address, value: account_id}, _int_val] ->
            Validate.id!(account_id)
        end
      end

    functions =
      AeMdw.Node.aex9_signatures()
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

    mutation =
      ContractCallMutation.new(
        contract_pk,
        call_txi,
        fun_arg_res,
        call_rec
      )

    {account_pk, mutation}
  end

  defp put_existing_nft(state, contract_pk, owner_pk, token_id) do
    state
    |> State.put(
      Model.NftOwnership,
      Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
    )
    |> State.put(
      Model.NftOwnerToken,
      Model.nft_owner_token(index: {contract_pk, owner_pk, token_id})
    )
    |> State.put(
      Model.NftTokenOwner,
      Model.nft_token_owner(index: {contract_pk, token_id}, owner: owner_pk)
    )
  end

  defp put_stats(state, contract_pk, nfts_count, owners_count) do
    nfts_count_key = Stats.nfts_count_key(contract_pk)
    nft_owners_count_key = Stats.nft_owners_count_key(contract_pk)

    state
    |> State.put(Model.Stat, Model.stat(index: nfts_count_key, payload: nfts_count))
    |> State.put(Model.Stat, Model.stat(index: nft_owners_count_key, payload: owners_count))
  end
end
