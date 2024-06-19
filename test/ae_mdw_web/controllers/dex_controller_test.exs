defmodule AeMdwWeb.DexControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Sync.DexCache
  alias AeMdw.Util.Encoding

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
            Model.dex_swap_tokens(index: {pair_txi, txi, log_idx})
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

    state = State.new(store)
    DexCache.add_pair(state, @pair1_pk, @token_pks[1], @token_pks[2])
    DexCache.add_pair(state, @pair2_pk, @token_pks[3], @token_pks[4])

    {:ok, store: store}
  end

  describe "swaps" do
    setup %{conn: conn, store: store} do
      {:ok, conn: with_store(conn, store)}
    end

    test "gets SwapTokens by desc txi", %{conn: conn} do
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

    test "gets SwapTokens by asc txi", %{conn: conn} do
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

  describe "account_tokens" do
    test "gets SwapTokens from a caller by desc txi", %{conn: conn, store: store} do
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

    test "gets SwapTokens from a caller by asc txi", %{conn: conn, store: store} do
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

    test "gets SwapTokens from a caller on a token by desc txi", %{conn: conn, store: store} do
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
           "amounts" => amounts
         },
         exp_token1,
         exp_token2
       ) do
    <<txi::256>> = Validate.id!(tx_hash)

    caller_id in @accounts and token1_symbol == exp_token1 and
      token2_symbol == exp_token2 and txi in 1_000_001..1_000_080 and log_idx == rem(txi, 2) and
      amounts == %{
        "amount0_in" => txi + 10,
        "amount1_in" => txi + 20,
        "amount0_out" => txi + 30,
        "amount1_out" => txi + 40
      }
  end
end
