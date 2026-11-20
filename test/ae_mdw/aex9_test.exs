defmodule AeMdw.Aex9Test do
  use ExUnit.Case, async: false

  alias AeMdw.Aex9
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.UpdateAex9StateMutation
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1, encode: 2]

  import Mock

  require Model

  describe "fetch_balances" do
    test "gets contract balances from async store" do
      contract_pk = :crypto.strong_rand_bytes(32)
      call_txi = 12_345_678

      balances =
        for _i <- 1..10, into: %{} do
          account_pk = :crypto.strong_rand_bytes(32)
          amount = Enum.random(1_000_000_000..9_999_999_999)
          {{:address, account_pk}, amount}
        end

      balances_list =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      table = :gets_contract_balances_from_async_store
      AsyncStore.init(table)

      async_state = State.new(AsyncStore.instance(table))

      Mutation.execute(
        UpdateAex9StateMutation.new(contract_pk, call_txi, balances_list),
        async_state
      )

      assert {:ok, ^balances} = Aex9.fetch_balances(State.new(), async_state, contract_pk, false)
    end
  end

  describe "fetch_balance" do
    test "gets latest account balance from the chain" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk, nil -> {:ok, {amount, <<1::256>>}} end
         ]}
      ] do
        assert {:ok,
                %{
                  contract: encode_contract(contract_pk),
                  account: encode_account(account_pk),
                  amount: amount
                }} == Aex9.fetch_balance(contract_pk, account_pk, nil)
      end
    end
  end

  describe "fetch_account_balances" do
    test "gets latest account balance from the chain" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)
      top_height_hash = Db.top_height_hash(true)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk, ^top_height_hash ->
             {:ok, {amount, top_height_hash}}
           end
         ]}
      ] do
        store =
          NullStore.new()
          |> MemStore.new()
          |> Store.put(
            Model.AexnContract,
            Model.aexn_contract(
              index: {:aex9, contract_pk},
              txi_idx: {100, -1},
              meta_info: {"name", "symbol", 18}
            )
          )
          |> Store.put(
            Model.Aex9AccountPresence,
            Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: 100)
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 100, id: <<101::256>>, block_index: {11, 0})
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {11, 0}, hash: <<111::256>>)
          )

        assert {:ok,
                {nil,
                 [
                   %{
                     contract_id: encode_contract(contract_pk),
                     amount: amount,
                     block_hash: encode(:micro_block_hash, <<111::256>>),
                     decimals: 18,
                     height: 11,
                     token_name: "name",
                     token_symbol: "symbol",
                     tx_hash: encode(:tx_hash, <<101::256>>),
                     tx_index: 100,
                     tx_type: :contract_create_tx
                   }
                 ],
                 nil}} ==
                 Aex9.fetch_account_balances(
                   State.new(store),
                   account_pk,
                   nil,
                   {:forward, false, 10, false}
                 )
      end
    end
  end

  describe "fetch_balance_history" do
    setup do
      {:ok, contract_pk: :crypto.strong_rand_bytes(32), account_pk: :crypto.strong_rand_bytes(32)}
    end

    test "starts the dry-runs after the contract creation height", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        assert {:ok, {nil, [first_item | _rest] = items, nil}} =
                 Aex9.fetch_balance_history(
                   history_state(contract_pk),
                   contract_pk,
                   account_pk,
                   nil,
                   nil,
                   {:forward, false, 10, false}
                 )

        assert [21, 22, 23] == Enum.map(items, & &1.height)

        assert %{
                 contract: encode_contract(contract_pk),
                 account: encode_account(account_pk),
                 amount: 210,
                 height: 21
               } == first_item

        assert 21 == dry_run_gens() |> Enum.min()
      end
    end

    test "stops the dry-runs after the contract creation height going backward", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        state = history_state(contract_pk)

        assert {:ok, {nil, items, {21, false}}} =
                 Aex9.fetch_balance_history(
                   state,
                   contract_pk,
                   account_pk,
                   {:gen, 0..23},
                   nil,
                   {:backward, false, 2, false}
                 )

        assert [23, 22] == Enum.map(items, & &1.height)

        assert {:ok, {{22, true}, [%{height: 21}], nil}} =
                 Aex9.fetch_balance_history(
                   state,
                   contract_pk,
                   account_pk,
                   {:gen, 0..23},
                   "21",
                   {:backward, false, 2, true}
                 )

        assert 21 == dry_run_gens() |> Enum.min()
      end
    end

    test "returns an empty page without dry-runs when the range ends at the creation height", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        for direction <- [:forward, :backward] do
          assert {:ok, {nil, [], nil}} =
                   Aex9.fetch_balance_history(
                     history_state(contract_pk),
                     contract_pk,
                     account_pk,
                     {:gen, 0..20},
                     nil,
                     {direction, false, 10, false}
                   )
        end

        assert [] == dry_run_gens()
      end
    end

    test "returns an empty page for a backward cursor before the creation", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        assert {:ok, {_prev_cursor, [], nil}} =
                 Aex9.fetch_balance_history(
                   history_state(contract_pk),
                   contract_pk,
                   account_pk,
                   {:gen, 0..23},
                   "10",
                   {:backward, false, 10, true}
                 )

        assert 21 == dry_run_gens() |> Enum.min()
      end
    end

    test "scans the whole range when the contract creation is unknown", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        assert {:ok, {nil, items, nil}} =
                 Aex9.fetch_balance_history(
                   blocks_state(),
                   contract_pk,
                   account_pk,
                   {:gen, 15..23},
                   nil,
                   {:forward, false, 10, false}
                 )

        assert [21, 22, 23] == Enum.map(items, & &1.height)
        assert 15 == dry_run_gens() |> Enum.min()
      end
    end

    test "never dry-runs below gen 0 when the contract creation is unknown", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        assert {:ok, {nil, [], nil}} =
                 Aex9.fetch_balance_history(
                   blocks_state(),
                   contract_pk,
                   account_pk,
                   {:gen, -5..2},
                   nil,
                   {:forward, false, 10, false}
                 )

        assert [0, 1, 2] == dry_run_gens()
      end
    end

    test "stops at the last indexed gen when the scope goes past it", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        state = history_state(contract_pk)

        for range <- [0..30, 21..999_999_999],
            {direction, heights} <- [forward: [21, 22, 23], backward: [23, 22, 21]] do
          assert {:ok, {nil, items, nil}} =
                   Aex9.fetch_balance_history(
                     state,
                     contract_pk,
                     account_pk,
                     {:gen, range},
                     nil,
                     {direction, false, 10, false}
                   )

          assert heights == Enum.map(items, & &1.height)
        end

        assert 23 == dry_run_gens() |> Enum.max()
      end
    end

    test "returns an empty page when the whole scope is past the last indexed gen", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        state = history_state(contract_pk)

        for range <- [25..25, 25..30], direction <- [:forward, :backward] do
          assert {:ok, {nil, [], nil}} =
                   Aex9.fetch_balance_history(
                     state,
                     contract_pk,
                     account_pk,
                     {:gen, range},
                     nil,
                     {direction, false, 10, false}
                   )
        end

        assert [] == dry_run_gens()
      end
    end

    test "keeps the cursor direction for a cursor past the last indexed gen", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        state = history_state(contract_pk)

        assert {:ok, {_prev_cursor, [], nil}} =
                 Aex9.fetch_balance_history(
                   state,
                   contract_pk,
                   account_pk,
                   {:gen, 0..30},
                   "25",
                   {:forward, false, 10, true}
                 )

        assert {:ok, {nil, items, nil}} =
                 Aex9.fetch_balance_history(
                   state,
                   contract_pk,
                   account_pk,
                   {:gen, 0..30},
                   "25",
                   {:backward, false, 10, true}
                 )

        assert [23, 22, 21] == Enum.map(items, & &1.height)
        assert 23 == dry_run_gens() |> Enum.max()
      end
    end

    test "returns an empty page when no generation is indexed", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        state = NullStore.new() |> MemStore.new() |> State.new()

        for range <- [nil, {:gen, 0..10}], direction <- [:forward, :backward] do
          assert {:ok, {nil, [], nil}} =
                   Aex9.fetch_balance_history(
                     state,
                     contract_pk,
                     account_pk,
                     range,
                     nil,
                     {direction, false, 10, false}
                   )
        end

        assert [] == dry_run_gens()
      end
    end

    test "rejects scopes that are not gen ranges", %{
      contract_pk: contract_pk,
      account_pk: account_pk
    } do
      with_mocks history_mocks(contract_pk, account_pk) do
        for scope <- [{:txi, 1..2}, {:epoch, 1..2}] do
          assert {:error,
                  %ErrInput{
                    reason: ErrInput.Scope,
                    message: "invalid scope: only gen scopes are supported"
                  }} =
                   Aex9.fetch_balance_history(
                     history_state(contract_pk),
                     contract_pk,
                     account_pk,
                     scope,
                     nil,
                     {:backward, false, 10, false}
                   )
        end

        assert [] == dry_run_gens()
      end
    end
  end

  # The contract is created in a micro block of generation 20, so its balance
  # can be dry-run from key block 21 on.
  defp history_state(contract_pk) do
    NullStore.new()
    |> MemStore.new()
    |> Store.put(Model.Field, Model.field(index: {:contract_create_tx, nil, contract_pk, 200}))
    |> Store.put(Model.Tx, Model.tx(index: 200, id: <<200::256>>, block_index: {20, 3}))
    |> Store.put(Model.Block, Model.block(index: {23, -1}))
    |> State.new()
  end

  defp blocks_state do
    NullStore.new()
    |> MemStore.new()
    |> Store.put(Model.Block, Model.block(index: {23, -1}))
    |> State.new()
  end

  defp history_mocks(contract_pk, account_pk) do
    [
      {AeMdw.Db.Util, [:passthrough], [height_hash: fn gen -> <<gen::256>> end]},
      {AeMdw.Node.Db, [:passthrough],
       [
         aex9_balance: fn ^contract_pk, ^account_pk, {:key, gen, _hash} = height_hash ->
           if gen > 20,
             do: {:ok, {gen * 10, height_hash}},
             else: {:error, :contract_does_not_exist}
         end
       ]}
    ]
  end

  defp dry_run_gens do
    for {_pid, {AeMdw.Node.Db, :aex9_balance, [_ct_pk, _acc_pk, {:key, gen, _hash}]}, _res} <-
          call_history(AeMdw.Node.Db),
        do: gen
  end
end
