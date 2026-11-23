defmodule AeMdwWeb.DexControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  import Mock

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Util.Encoding
  alias AeMdw.Validate

  require Model

  @pair1_pk :crypto.strong_rand_bytes(32)
  @pair2_pk :crypto.strong_rand_bytes(32)
  @pair1_txi 200_001
  @pair2_txi 200_002

  @token_pks Map.new(1..4, fn i -> {i, :crypto.strong_rand_bytes(32)} end)
  @token_txis Map.new(1..4, fn i -> {i, 100_000 + i} end)

  @account1_pk <<1::256>>
  @account2_pk <<2::256>>
  @accounts [encode_account(@account1_pk), encode_account(@account2_pk)]

  @default_limit 10

  setup_all do
    store =
      1..4
      |> Enum.reduce(empty_store(), fn i, store ->
        Store.put(
          store,
          Model.AexnContract,
          Model.aexn_contract(
            index: {:aex9, @token_pks[i]},
            txi_idx: {@token_txis[i], -1},
            meta_info: {"TOKEN#{i}", "TK#{i}", 18}
          )
        )
      end)
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @pair1_pk, @pair1_txi})
      )
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @pair2_pk, @pair2_txi})
      )
      |> then(fn store ->
        Enum.reduce(1..80, store, fn i, store ->
          {account_pk, pair_txi} =
            cond do
              i <= 20 ->
                {@account1_pk, @pair1_txi}

              i <= 40 ->
                {@account1_pk, @pair2_txi}

              i <= 60 ->
                {@account2_pk, @pair1_txi}

              true ->
                {@account2_pk, @pair2_txi}
            end

          txi = 1_000_000 + i
          log_idx = rem(txi, 2)
          block_index_number = 200_000 + i
          block_index = {block_index_number, -1}
          token1_pk = :crypto.strong_rand_bytes(32)
          token2_pk = :crypto.strong_rand_bytes(32)

          store
          |> Store.put(
            Model.DexAccountSwapTokens,
            Model.dex_account_swap_tokens(
              index: {account_pk, pair_txi, txi, log_idx},
              to: account_pk,
              amounts: [txi + 10, txi + 20, txi + 30, txi + 40]
            )
          )
          |> Store.put(
            Model.DexContractSwapTokens,
            Model.dex_contract_swap_tokens(index: {pair_txi, account_pk, txi, log_idx})
          )
          |> Store.put(
            Model.DexSwapTokens,
            Model.dex_swap_tokens(index: {txi, log_idx, pair_txi})
          )
          |> Store.put(
            Model.ContractLog,
            Model.contract_log(
              index: {pair_txi, txi, log_idx},
              args: [account_pk, account_pk]
            )
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: txi, id: <<txi::256>>, block_index: {100_000 + i, 0})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: pair_txi, id: <<pair_txi::256>>, block_index: block_index)
          )
          |> Store.put(
            Model.Block,
            Model.block(index: block_index, tx_index: txi, hash: <<block_index_number::256>>)
          )
          |> Store.put(
            Model.AexnContract,
            Model.aexn_contract(index: {:aex9, token1_pk}, meta_info: {"TOKEN1", "TK1", 18})
          )
          |> Store.put(
            Model.AexnContract,
            Model.aexn_contract(index: {:aex9, token2_pk}, meta_info: {"TOKEN2", "TK2", 18})
          )
          |> Store.put(
            Model.Field,
            Model.field(
              index: {:contract_create_tx, nil, <<block_index_number::256>>, block_index_number}
            )
          )
        end)
      end)
      |> then(fn store ->
        Enum.reduce(1..4, store, fn i, store ->
          Store.put(
            store,
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, @token_pks[i], @token_txis[i]})
          )
        end)
      end)
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(
          index: {{@pair1_txi, -1}, :contract_create_tx},
          pubkey: @pair1_pk
        )
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(
          index: {{@pair2_txi, -1}, :contract_create_tx},
          pubkey: @pair2_pk
        )
      )
      |> Store.put(
        Model.DexPair,
        Model.dex_pair(index: @pair1_pk, token1_pk: @token_pks[1], token2_pk: @token_pks[2])
      )
      |> Store.put(
        Model.DexPair,
        Model.dex_pair(index: @pair2_pk, token1_pk: @token_pks[3], token2_pk: @token_pks[4])
      )

    {:ok, store: store}
  end

  describe "swaps" do
    setup %{conn: conn, store: store} do
      {:ok, conn: with_store(conn, store)}
    end

    test "gets SwapTokens by desc txi", %{conn: conn} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account2_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> get("/v3/dex/swaps")
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]), :desc)
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]), :desc)

        assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

        assert %{"data" => ^swaps} = conn |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets SwapTokens by asc txi", %{conn: conn} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account1_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> get("/v3/dex/swaps", direction: :forward)
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]))
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]))

        assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => ^swaps} = conn |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets scoped SwapTokens", %{conn: conn} do
      first_gen = 200_001
      last_gen = 200_002

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account1_pk)

        assert %{"data" => swaps, "next" => nil} =
                 conn
                 |> get("/v3/dex/swaps", scope: "gen:#{first_gen}-#{last_gen}")
                 |> json_response(200)

        assert 2 = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Map.fetch!(&1, "height"), :desc)
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))
      end
    end

    test "gets SwapTokens from both external and parent contracts", %{conn: conn} do
      caller_id = encode_account(@account1_pk)
      pair_pk = <<3::256>>
      parent_contract_pk = <<4::256>>
      ext_contract_pk = <<5::256>>
      parent_contract_pk2 = <<6::256>>
      ext_contract_pk2 = <<7::256>>

      pair_txi = 1
      ext_contract_txi = 2
      parent_contract_txi = 3
      parent_contract2_txi = 4
      ext_contract2_txi = 4

      txi1 = 5
      txi2 = 6
      txi3 = 7
      txi4 = 8

      log_idx = 0

      store =
        empty_store()
        # CASE 1
        |> Store.put(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {txi1, log_idx, pair_txi})
        )
        |> Store.put(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {@account1_pk, pair_txi, txi1, log_idx},
            to: @account2_pk,
            amounts: [90, 91, 92, 93]
          )
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, pair_pk, pair_txi})
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {pair_txi, txi1, log_idx},
            args: [@account1_pk, @account2_pk]
          )
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: txi1, id: <<txi1::256>>, block_index: {100_001, 0})
        )
        # CASE 2
        |> Store.put(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {txi2, log_idx, pair_txi})
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {pair_txi, txi2, log_idx},
            ext_contract: ext_contract_pk,
            args: [@account1_pk, @account2_pk]
          )
        )
        |> Store.put(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {@account1_pk, pair_txi, txi2, log_idx},
            to: @account2_pk,
            amounts: [94, 95, 96, 97]
          )
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, ext_contract_pk, ext_contract_txi})
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: txi2, id: <<txi2::256>>, block_index: {200_002, 0})
        )
        # CASE 3
        |> Store.put(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {txi3, log_idx, pair_txi})
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {pair_txi, txi3, log_idx},
            ext_contract: {:parent_contract_pk, parent_contract_pk},
            args: [@account1_pk, @account2_pk]
          )
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {parent_contract_txi, txi3, log_idx},
            ext_contract: nil
          )
        )
        |> Store.put(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {@account1_pk, pair_txi, txi3, log_idx},
            to: @account2_pk,
            amounts: [98, 99, 100, 101]
          )
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, parent_contract_pk, parent_contract_txi})
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: txi3, id: <<txi3::256>>, block_index: {300_003, 0})
        )
        # CASE 4
        |> Store.put(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {txi4, log_idx, pair_txi})
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {pair_txi, txi4, log_idx},
            ext_contract: {:parent_contract_pk, parent_contract_pk2},
            args: [@account1_pk, @account2_pk]
          )
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(
            index: {parent_contract2_txi, txi4, log_idx},
            ext_contract: ext_contract_pk2
          )
        )
        |> Store.put(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {@account1_pk, pair_txi, txi4, log_idx},
            to: @account2_pk,
            amounts: [102, 103, 104, 105]
          )
        )
        |> Store.put(
          Model.Field,
          Model.field(
            index: {:contract_create_tx, nil, parent_contract_pk2, parent_contract2_txi}
          )
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, ext_contract_pk2, ext_contract2_txi})
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: txi4, id: <<txi4::256>>, block_index: {400_004, 0})
        )
        |> add_supporting_dex_data(pair_txi, "TK11", "TK12")
        |> add_supporting_dex_data(ext_contract_txi, "TK13", "TK14")
        |> add_supporting_dex_data(parent_contract_txi, "TK15", "TK16")
        |> add_supporting_dex_data(parent_contract2_txi, "TK17", "TK18")

      # :ets.insert(:dex_pairs_symbols, {pair_txi, "TK11", "TK12"})
      # :ets.insert(:dex_pairs_symbols, {ext_contract_txi, "TK13", "TK14"})
      # :ets.insert(:dex_pairs_symbols, {parent_contract_txi, "TK15", "TK16"})
      # :ets.insert(:dex_pairs_symbols, {ext_contract2_txi, "TK17", "TK18"})

      assert %{"data" => swaps, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/dex/swaps", direction: :forward, limit: 2)
               |> json_response(200)

      assert 2 = length(swaps)

      assert [
               %{
                 "amounts" => %{
                   "amount0_in" => 90,
                   "amount0_out" => 92,
                   "amount1_in" => 91,
                   "amount1_out" => 93
                 },
                 "caller" => ^caller_id,
                 "from_token" => "TK11",
                 "log_idx" => 0,
                 "to_token" => "TK12"
               },
               %{
                 "amounts" => %{
                   "amount0_in" => 94,
                   "amount0_out" => 96,
                   "amount1_in" => 95,
                   "amount1_out" => 97
                 },
                 "caller" => ^caller_id,
                 "from_token" => "TK13",
                 "log_idx" => 0,
                 "to_token" => "TK14"
               }
             ] = swaps

      assert %{"data" => next_swaps, "prev" => prev_swaps} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert 2 = length(next_swaps)

      assert [
               %{
                 "amounts" => %{
                   "amount0_in" => 98,
                   "amount0_out" => 100,
                   "amount1_in" => 99,
                   "amount1_out" => 101
                 },
                 "caller" => ^caller_id,
                 "from_token" => "TK15",
                 "log_idx" => 0,
                 "to_token" => "TK16"
               },
               %{
                 "amounts" => %{
                   "amount0_in" => 102,
                   "amount0_out" => 104,
                   "amount1_in" => 103,
                   "amount1_out" => 105
                 },
                 "caller" => ^caller_id,
                 "from_token" => "TK17",
                 "log_idx" => 0,
                 "to_token" => "TK18"
               }
             ] = next_swaps

      assert %{"data" => ^swaps} =
               conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
    end
  end

  describe "account_tokens" do
    test "gets SwapTokens from a caller by desc txi", %{conn: conn, store: store} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account1_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/accounts/#{caller_id}/dex/swaps")
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]), :desc)
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> with_store(store) |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]), :desc)

        assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

        assert %{"data" => ^swaps} =
                 conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets SwapTokens from a caller by asc txi", %{conn: conn, store: store} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account2_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/accounts/#{caller_id}/dex/swaps", direction: :forward)
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]))
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> with_store(store) |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]))

        assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => ^swaps} =
                 conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets SwapTokens from a caller on a token by desc txi", %{conn: conn, store: store} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        caller_id = encode_account(@account1_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/accounts/#{caller_id}/dex/swaps", token_symbol: "TK1")
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]), :desc)
        assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> with_store(store) |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]), :desc)

        assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK1", "TK2"))

        assert %{"data" => ^swaps} =
                 conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets SwapTokens from a caller on a token by asc txi", %{conn: conn, store: store} do
      caller_id = encode_account(@account2_pk)

      assert %{"data" => swaps, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/accounts/#{caller_id}/dex/swaps",
                 token_symbol: "TK3",
                 direction: :forward
               )
               |> json_response(200)

      assert @default_limit = length(swaps)
      assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]))
      assert Enum.all?(swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

      assert %{"data" => next_swaps, "prev" => prev_swaps} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_swaps)

      assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]))

      assert Enum.all?(next_swaps, &valid_caller_swap?(&1, caller_id, "TK3", "TK4"))

      assert %{"data" => ^swaps} =
               conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
    end

    test "gets SwapTokens from a caller on every pair with the token symbol", %{
      conn: conn,
      store: store
    } do
      caller_id = encode_account(@account1_pk)
      # a MemStore over the shared one, so the extra pairs don't leak into other tests
      store = store |> MemStore.new() |> add_symbol_pairs()
      path = "/v3/accounts/#{caller_id}/dex/swaps"

      # pairs in create txi order, newest first
      tk1_swaps =
        Enum.map(1_000_090..1_000_086//-1, &{&1, "TK1", "TK4"}) ++
          Enum.map(1_000_085..1_000_081//-1, &{&1, "TK1", "TK3"}) ++
          Enum.map(1_000_020..1_000_001//-1, &{&1, "TK1", "TK2"})

      tk3_swaps =
        Enum.map(1_000_085..1_000_081//-1, &{&1, "TK1", "TK3"}) ++
          Enum.map(1_000_040..1_000_021//-1, &{&1, "TK3", "TK4"})

      assert ^tk1_swaps = fetch_all_swaps(conn, store, "#{path}?token_symbol=TK1&limit=7")

      assert Enum.reverse(tk1_swaps) ==
               fetch_all_swaps(conn, store, "#{path}?token_symbol=TK1&limit=7&direction=forward")

      assert ^tk3_swaps = fetch_all_swaps(conn, store, "#{path}?token_symbol=TK3&limit=7")

      assert %{"data" => page1, "next" => next} =
               conn
               |> with_store(store)
               |> get(path, token_symbol: "TK1", limit: 7)
               |> json_response(200)

      assert %{"prev" => prev} = conn |> with_store(store) |> get(next) |> json_response(200)
      assert %{"data" => ^page1} = conn |> with_store(store) |> get(prev) |> json_response(200)
    end

    test "gets scoped SwapTokens from a caller on a token symbol", %{conn: conn, store: store} do
      caller_id = encode_account(@account1_pk)

      # gens 200_003..200_005 hold txis 1_000_003..1_000_005
      assert [
               {1_000_003, "TK1", "TK2"},
               {1_000_004, "TK1", "TK2"},
               {1_000_005, "TK1", "TK2"}
             ] =
               fetch_all_swaps(
                 conn,
                 store,
                 "/v3/accounts/#{caller_id}/dex/swaps?token_symbol=TK1&scope=gen:200003-200005"
               )
    end

    test "returns bad request when no pair has the token symbol", %{conn: conn, store: store} do
      caller_id = encode_account(@account1_pk)

      assert %{"error" => "not AEX9 contract: TK9"} =
               conn
               |> with_store(store)
               |> get("/v3/accounts/#{caller_id}/dex/swaps", token_symbol: "TK9")
               |> json_response(400)
    end

    test "returns empty list when no transfer exists", %{conn: conn, store: store} do
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/accounts/#{account_id_without_transfer}/dex/swaps")
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/accounts/#{invalid_id}/dex/swaps")
               |> json_response(400)
    end
  end

  describe "contract_swaps" do
    test "gets SwapTokens from a contract_id by desc txi", %{conn: conn, store: store} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn _mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn _contract_pk, {:micro, _test, _mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        contract_id = Encoding.encode_contract(@pair1_pk)

        assert %{"data" => swaps, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/dex/#{contract_id}/swaps")
                 |> json_response(200)

        assert @default_limit = length(swaps)
        assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]), :desc)
        assert Enum.all?(swaps, &valid_token_swap?(&1, "TK1", "TK2"))

        assert %{"data" => next_swaps, "prev" => prev_swaps} =
                 conn |> with_store(store) |> get(next) |> json_response(200)

        assert @default_limit = length(next_swaps)

        assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]), :desc)

        assert Enum.all?(next_swaps, &valid_token_swap?(&1, "TK1", "TK2"))

        assert %{"data" => ^swaps} =
                 conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
      end
    end

    test "gets SwapTokens from a contract_id by asc txi", %{conn: conn, store: store} do
      contract_id = Encoding.encode_contract(@pair2_pk)

      assert %{"data" => swaps, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/dex/#{contract_id}/swaps", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(swaps)
      assert ^swaps = Enum.sort_by(swaps, &Validate.id!(&1["tx_hash"]))
      assert Enum.all?(swaps, &valid_token_swap?(&1, "TK3", "TK4"))

      assert %{"data" => next_swaps, "prev" => prev_swaps} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_swaps)

      assert ^next_swaps = Enum.sort_by(next_swaps, &Validate.id!(&1["tx_hash"]))

      assert Enum.all?(next_swaps, &valid_token_swap?(&1, "TK3", "TK4"))

      assert %{"data" => ^swaps} =
               conn |> with_store(store) |> get(prev_swaps) |> json_response(200)
    end

    test "returns bad request when contract_id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/dex/#{invalid_id}/swaps")
               |> json_response(400)
    end
  end

  defp valid_caller_swap?(
         %{
           "caller" => caller_id,
           "to_account" => caller_id,
           "from_token" => token1_symbol,
           "to_token" => token2_symbol,
           "tx_hash" => tx_hash,
           "log_idx" => log_idx,
           "amounts" => amounts
         },
         exp_caller_id,
         exp_token1,
         exp_token2
       ) do
    <<txi::256>> = Validate.id!(tx_hash)

    exp_caller_id == caller_id and token1_symbol == exp_token1 and
      token2_symbol == exp_token2 and txi in 1_000_001..1_000_080 and log_idx == rem(txi, 2) and
      amounts == %{
        "amount0_in" => txi + 10,
        "amount1_in" => txi + 20,
        "amount0_out" => txi + 30,
        "amount1_out" => txi + 40
      }
  end

  defp valid_token_swap?(
         %{
           "caller" => caller_id,
           "to_account" => caller_id,
           "from_token" => token1_symbol,
           "to_token" => token2_symbol,
           "tx_hash" => tx_hash,
           "log_idx" => log_idx,
           "amounts" => amounts,
           "action" => action,
           "micro_time" => _micro_time,
           "from_contract" => _from_contract,
           "to_contract" => _to_contract,
           "from_amount" => _from_amount,
           "to_amount" => _to_amount,
           "from_decimals" => _from_decimals,
           "to_decimals" => _to_decimals,
           "height" => _height
         },
         exp_token1,
         exp_token2
       ) do
    <<txi::256>> = Validate.id!(tx_hash)

    caller_id in @accounts and token1_symbol == exp_token1 and
      action in ["SELL", "BUY", "SWAP"] and
      token2_symbol == exp_token2 and txi in 1_000_001..1_000_080 and log_idx == rem(txi, 2) and
      amounts == %{
        "amount0_in" => txi + 10,
        "amount1_in" => txi + 20,
        "amount0_out" => txi + 30,
        "amount1_out" => txi + 40
      }
  end

  defp fetch_all_swaps(conn, store, path) do
    %{"data" => swaps, "next" => next} =
      conn |> with_store(store) |> get(path) |> json_response(200)

    swaps =
      Enum.map(swaps, fn %{"tx_hash" => tx_hash, "from_token" => from, "to_token" => to} ->
        <<txi::256>> = Validate.id!(tx_hash)
        {txi, from, to}
      end)

    if next, do: swaps ++ fetch_all_swaps(conn, store, next), else: swaps
  end

  # Adds a second TK1/TK3 pair and a pair of another token also named TK1, with
  # account1 swaps on both.
  defp add_symbol_pairs(store) do
    token5_pk = :crypto.strong_rand_bytes(32)

    store =
      Store.put(
        store,
        Model.AexnContract,
        Model.aexn_contract(index: {:aex9, token5_pk}, meta_info: {"TOKEN5", "TK1", 18})
      )

    [
      {300_001, @token_pks[1], @token_pks[3], 1_000_081..1_000_085},
      {300_002, token5_pk, @token_pks[4], 1_000_086..1_000_090}
    ]
    |> Enum.reduce(store, fn {pair_txi, token1_pk, token2_pk, txis}, store ->
      pair_pk = :crypto.strong_rand_bytes(32)

      store =
        store
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, pair_pk, pair_txi})
        )
        |> Store.put(
          Model.RevOrigin,
          Model.rev_origin(index: {{pair_txi, -1}, :contract_create_tx}, pubkey: pair_pk)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: pair_txi, id: <<pair_txi::256>>, block_index: {pair_txi, -1})
        )
        |> Store.put(
          Model.DexPair,
          Model.dex_pair(index: pair_pk, token1_pk: token1_pk, token2_pk: token2_pk)
        )

      Enum.reduce(txis, store, fn txi, store ->
        store
        |> Store.put(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {@account1_pk, pair_txi, txi, 0},
            to: @account1_pk,
            amounts: [1, 2, 3, 4]
          )
        )
        |> Store.put(
          Model.ContractLog,
          Model.contract_log(index: {pair_txi, txi, 0}, args: [@account1_pk, @account1_pk])
        )
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: {txi, 0}))
      end)
    end)
  end

  defp add_supporting_dex_data(store, txi, token1_symbol, token2_symbol) do
    block_index_number = 900_000 + txi
    block_index = {block_index_number, 0}
    token1_pk = :crypto.strong_rand_bytes(32)
    token2_pk = :crypto.strong_rand_bytes(32)
    pair_pk = <<block_index_number::256>>

    store
    |> Store.put(
      Model.Tx,
      Model.tx(
        index: txi,
        id: <<txi::256>>,
        block_index: block_index
      )
    )
    |> Store.put(
      Model.Block,
      Model.block(
        index: block_index,
        tx_index: txi,
        hash: <<block_index_number::256>>
      )
    )
    |> Store.put(
      Model.RevOrigin,
      Model.rev_origin(
        index: {{txi, -1}, :contract_create_tx},
        pubkey: <<block_index_number::256>>
      )
    )
    |> Store.put(
      Model.Field,
      Model.field(index: {:contract_create_tx, nil, pair_pk, block_index_number})
    )
    |> Store.put(
      Model.AexnContract,
      Model.aexn_contract(index: {:aex9, token1_pk}, meta_info: {"TOKEN1", token1_symbol, 18})
    )
    |> Store.put(
      Model.AexnContract,
      Model.aexn_contract(index: {:aex9, token2_pk}, meta_info: {"TOKEN2", token2_symbol, 18})
    )
    |> Store.put(
      Model.DexPair,
      Model.dex_pair(index: pair_pk, token1_pk: token1_pk, token2_pk: token2_pk)
    )
  end
end
