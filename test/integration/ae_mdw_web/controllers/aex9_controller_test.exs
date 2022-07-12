defmodule Integration.AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper

  require Model

  @moduletag :integration

  @big_balance_contract_id1 "ct_BwJcRRa7jTAvkpzc2D16tJzHMGCJurtJMUBtyyfGi2QjPuMVv"
  @big_balance_contract_id2 "ct_uGk1rkSdccPKXLzS259vdrJGTWAY9sfgVYspv6QYomxvWZWBM"
  @big_balance_contract_id3 "ct_M9yohHgcLjhpp1Z8SaA1UTmRMQzR4FWjJHajGga8KBoZTEPwC"

  @default_limit 10

  describe "by_contract" do
    test "gets an aex9 token by contract id", %{conn: conn} do
      contract_id = "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt"

      response =
        conn
        |> get("/aex9/by_contract/#{contract_id}")
        |> json_response(200)

      assert response["data"] ==
               %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG",
                 "extensions" => ["allowances", "mintable", "burnable", "swappable"]
               }

      contract_id = "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer"

      response =
        conn
        |> get("/aex9/by_contract/#{contract_id}")
        |> json_response(200)

      assert response["data"] ==
               %{
                 "contract_id" => "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer",
                 "contract_txi" => 9_393_007,
                 "decimals" => 18,
                 "name" => "AAA",
                 "symbol" => "AAA",
                 "extensions" => []
               }
    end

    @tag :iteration
    test "gets each of the aex9 tokens by contract id", %{conn: conn} do
      state = State.new()

      Model.AexnContract
      |> Database.all_keys()
      |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)
      |> Enum.each(fn {:aex9, aex9_pubkey} ->
        contract_id = enc_ct(aex9_pubkey)

        response =
          conn
          |> get("/aex9/by_contract/#{contract_id}")
          |> json_response(200)

        assert %{
                 "contract_id" => ^contract_id,
                 "contract_txi" => contract_txi,
                 "decimals" => decimals,
                 "name" => name,
                 "symbol" => symbol
               } = response["data"]

        assert contract_txi == Origin.tx_index!(state, {:contract, aex9_pubkey})
        assert is_binary(name)
        assert is_binary(symbol)

        if name == "out_of_gas_error" do
          assert is_nil(decimals)
        else
          assert is_integer(decimals) and decimals >= 0
        end
      end)
    end
  end

  describe "by_name" do
    test "gets aex9 tokens sorted by name", %{conn: conn} do
      response =
        conn
        |> get("/aex9/by_name")
        |> json_response(200)

      assert Enum.any?(response, fn aex9 ->
               aex9 == %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG",
                 "extensions" => ["allowances", "mintable", "burnable", "swappable"]
               }
             end)

      assert Enum.any?(response, fn aex9 ->
               aex9 ==
                 %{
                   "contract_id" => "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer",
                   "contract_txi" => 9_393_007,
                   "decimals" => 18,
                   "name" => "AAA",
                   "symbol" => "AAA",
                   "extensions" => []
                 }
             end)
    end
  end

  describe "by_symbol" do
    test "gets aex9 tokens sorted by symbol", %{conn: conn} do
      response =
        conn
        |> get("/aex9/by_symbol")
        |> json_response(200)

      assert Enum.any?(response, fn aex9 ->
               aex9 ==
                 %{
                   "contract_id" => "ct_2TZsPKT5wyahqFrzp8YX7DfXQapQ4Qk65yn3sHbifU9Db9hoav",
                   "contract_txi" => 12_361_891,
                   "decimals" => 18,
                   "name" => "911058",
                   "symbol" => "SPH",
                   "extensions" => ["allowances", "mintable", "burnable", "swappable"]
                 }
             end)

      assert Enum.any?(response, fn aex9 ->
               aex9 == %{
                 "contract_id" => "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
                 "contract_txi" => 22_313_168,
                 "decimals" => 18,
                 "name" => "9GAG",
                 "symbol" => "9GAG",
                 "extensions" => ["allowances", "mintable", "burnable", "swappable"]
               }
             end)
    end
  end

  describe "balance_range" do
    test "gets account balance on a contract for range of generations", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      account_id = "ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"
      first = 489_501
      last = 489_510

      path =
        Routes.aex9_path(
          conn,
          :balance_range,
          "#{first}-#{last}",
          contract_id,
          account_id
        )

      response = conn |> get(path) |> json_response(200)
      assert response["contract_id"] == contract_id
      assert response["account_id"] == account_id
      assert is_list(response["range"])

      response["range"]
      |> Enum.zip(first..last)
      |> Enum.each(fn {height_map, height} ->
        assert %{
                 "amount" => amount,
                 "block_hash" => hash,
                 "height" => ^height
               } = height_map

        assert (height < 489_509 && amount == 9_975_045) || amount == 9_975_135
        assert String.starts_with?(hash, "kh_") and match?({:ok, _hash_bin}, Validate.id(hash))
      end)
    end

    test "returns 404 if contract had not been created up to the block", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      account_id = "ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"
      first = 487_100
      last = 487_101

      path =
        Routes.aex9_path(
          conn,
          :balance_range,
          "#{first}-#{last}",
          contract_id,
          account_id
        )

      assert %{"error" => error} = conn |> get(path) |> json_response(404)
      assert error == "not found: #{contract_id}"
    end
  end

  describe "balances_range" do
    test "gets balances on a contract for range of generations", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      first = 489_501
      last = 489_510

      path =
        Routes.aex9_path(
          conn,
          :balances_range,
          "#{first}-#{last}",
          "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
        )

      response = conn |> get(path) |> json_response(200)
      assert response["contract_id"] == contract_id
      assert is_list(response["range"])

      response["range"]
      |> Enum.zip(first..last)
      |> Enum.each(fn {height_map, height} ->
        assert %{
                 "amounts" => amounts,
                 "block_hash" => hash,
                 "height" => ^height
               } = height_map

        assert (height < 489_509 &&
                  amounts["ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"] == 9_975_045) ||
                 amounts["ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"] == 9_975_135

        assert String.starts_with?(hash, "kh_") and match?({:ok, _hash_bin}, Validate.id(hash))
      end)
    end

    test "returns 404 if contract had not been created up to the block", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      first = 487_100
      last = 487_101

      path =
        Routes.aex9_path(
          conn,
          :balances_range,
          "#{first}-#{last}",
          contract_id
        )

      assert %{"error" => error} = conn |> get(path) |> json_response(404)
      assert error == "not found: #{contract_id}"
    end

    @tag :iteration
    test "gets balances on each contract for a range of generations", %{conn: conn} do
      first = 500_001
      last = 500_003
      state = State.new()

      Model.block(tx_index: range_txi) = Database.fetch!(Model.Block, {first, -1})

      Model.AexnContract
      |> Database.all_keys()
      |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)
      |> Enum.filter(fn {:aex9, contract_pk} ->
        Origin.tx_index!(state, {:contract, contract_pk}) < range_txi and
          enc_ct(contract_pk) not in [
            @big_balance_contract_id1,
            @big_balance_contract_id2,
            @big_balance_contract_id3
          ]
      end)
      |> Enum.each(fn {:aex9, aex9_pubkey} ->
        contract_id = enc_ct(aex9_pubkey)

        path =
          Routes.aex9_path(
            conn,
            :balances_range,
            "#{first}-#{last}",
            contract_id
          )

        response = conn |> get(path) |> json_response(200)
        assert response["contract_id"] == contract_id
        assert is_list(response["range"])

        response["range"]
        |> Enum.zip(first..last)
        |> Enum.each(fn {height_map, height} ->
          assert %{
                   "amounts" => amounts,
                   "block_hash" => hash,
                   "height" => ^height
                 } = height_map

          assert is_map(amounts)
          assert String.starts_with?(hash, "kh_") and match?({:ok, _hash_bin}, Validate.id(hash))
        end)
      end)
    end
  end

  describe "balance_for_hash" do
    test "gets balance for hash", %{conn: conn} do
      mb_hash = "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      account_id = "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      conn = get(conn, "/aex9/balance/hash/#{mb_hash}/#{contract_id}/#{account_id}")

      assert %{
               "account_id" => "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
               "amount" => 49_999_999_999_906_850_000_000_000,
               "block_hash" => ^mb_hash,
               "contract_id" => ^contract_id,
               "height" => 350_622
             } = json_response(conn, 200)
    end

    test "returns 404 if contract had not been created up to the block", %{conn: conn} do
      hash = "kh_NM2cxdzg6mf4KMFMXw1kAzBJGwFoqiGHQtaKx3DvaAGM5CAkn"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      account_id = "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      conn = get(conn, "/aex9/balance/hash/#{hash}/#{contract_id}/#{account_id}")

      assert %{"error" => error} = json_response(conn, 404)
      assert error == "not found: #{contract_id}"
    end
  end

  describe "balances_for_hash" do
    test "gets balances for hash and contract", %{conn: conn} do
      mb_hash = "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/aex9/balances/hash/#{mb_hash}/#{contract_id}")

      assert %{
               "amounts" => %{
                 "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6" => 4_050_000_000_000,
                 "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK" => 8_100_000_000_000,
                 "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4" => 81_000_000_000_000,
                 "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48" =>
                   49_999_999_999_906_850_000_000_000
               },
               "block_hash" => ^mb_hash,
               "contract_id" => ^contract_id,
               "height" => 350_622
             } = json_response(conn, 200)
    end

    test "returns 404 if contract had not been created up to the block", %{conn: conn} do
      hash = "kh_NM2cxdzg6mf4KMFMXw1kAzBJGwFoqiGHQtaKx3DvaAGM5CAkn"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/aex9/balances/hash/#{hash}/#{contract_id}")

      assert %{"error" => error} = json_response(conn, 404)
      assert error == "not found: #{contract_id}"
    end

    @tag :iteration
    test "gets balances for some hashes and each contract", %{conn: conn} do
      mb_hashes =
        [
          {300_001, 1},
          {400_002, 2},
          {500_003, 3}
        ]
        |> Enum.map(&Database.fetch!(Model.Block, &1))
        |> Enum.map(fn Model.block(tx_index: txi, hash: mb_hash) ->
          {txi, :aeser_api_encoder.encode(:micro_block_hash, mb_hash)}
        end)

      state = State.new()

      Model.AexnContract
      |> Database.all_keys()
      |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)
      |> Enum.map(fn {:aex9, ct_pk} -> enc_ct(ct_pk) end)
      |> Enum.zip(mb_hashes)
      |> Enum.filter(fn {contract_id, {_mb_hash, mb_txi}} ->
        ct_pk = Validate.id!(contract_id)
        Origin.tx_index!(state, {:contract, ct_pk}) > mb_txi
      end)
      |> Enum.each(fn {contract_id, {mb_hash, _mb_txi}} ->
        conn = get(conn, "/aex9/balances/hash/#{mb_hash}/#{contract_id}")

        assert %{
                 "amounts" => amounts,
                 "block_hash" => ^mb_hash,
                 "contract_id" => ^contract_id,
                 "height" => height
               } = json_response(conn, 200)

        assert is_map(amounts)
        assert height in [300_001, 400_002, 500_003]
      end)
    end
  end

  describe "block account balances" do
    test "gets account balances up to a block", %{conn: conn} do
      mb_height = 434_825
      mb_hash = "mh_iDZvfWrZ8QEFaBW9nGzrTv1KBPMh2dVW4z2Bn7NBALLqwFRB9"
      account_id = "ak_3n5eTrEzg2VDQK7Y2XJdShVeaDsdpZggA8JvpukGpwEKkiorv"
      conn = get(conn, "/aex9/balances/hash/#{mb_hash}/account/#{account_id}")

      response_list = json_response(conn, 200)

      assert Enum.any?(response_list, fn balance ->
               balance == %{
                 "amount" => 1_000_000_000_000_000_000_000_000_000_000_000_000,
                 "block_hash" => "mh_2am5eS1a8Y2Mo8Lj8a1Bn1UNDNpEeaACbGrGcs2pEBg8hLHaZA",
                 "contract_id" => "ct_27ZrSPGoNH2waapYtu4upxDnk2g39dbSzmmZiYP7SGJ4XPb6jM",
                 "height" => 434_825,
                 "token_name" => "Aeternity",
                 "token_symbol" => "Aeternity",
                 "tx_hash" => "th_ZoRHbdJbx6NM2nu3QBDFmPm2e1uX1RpdrhLVrwj67BYxMbTwe",
                 "tx_index" => 22_699_236,
                 "tx_type" => "contract_create_tx"
               }
             end)

      assert Enum.all?(response_list, fn %{"height" => height} -> height <= mb_height end)

      assert length(response_list) == 10
    end

    test "gets account balances up to a height", %{conn: conn} do
      kb_height = 434_825
      account_id = "ak_3n5eTrEzg2VDQK7Y2XJdShVeaDsdpZggA8JvpukGpwEKkiorv"
      conn = get(conn, "/aex9/balances/gen/#{kb_height}/account/#{account_id}")

      response_list = json_response(conn, 200)

      refute Enum.any?(response_list, fn balance ->
               balance == %{
                 "amount" => 1_000_000_000_000_000_000_000_000_000_000_000_000,
                 "block_hash" => "mh_2am5eS1a8Y2Mo8Lj8a1Bn1UNDNpEeaACbGrGcs2pEBg8hLHaZA",
                 "contract_id" => "ct_27ZrSPGoNH2waapYtu4upxDnk2g39dbSzmmZiYP7SGJ4XPb6jM",
                 "height" => 434_825,
                 "token_name" => "Aeternity",
                 "token_symbol" => "Aeternity",
                 "tx_hash" => "th_ZoRHbdJbx6NM2nu3QBDFmPm2e1uX1RpdrhLVrwj67BYxMbTwe",
                 "tx_index" => 22_699_236,
                 "tx_type" => "contract_create_tx"
               }
             end)

      assert Enum.any?(response_list, fn balance ->
               balance == %{
                 "amount" => 1_000_000_000_000_000_000_000_000_000_000_000_000_000,
                 "block_hash" => "mh_DqYipPQJzmffuG9FJjvmSEdydozWs4XuDKqayUSUXzeHrFx6Z",
                 "contract_id" => "ct_UU9BxMBjxLijyjCa6Cxeopd2xuB2G2pJfHAbvn8Ky6DSMPSXo",
                 "height" => 417_168,
                 "token_name" => "Air",
                 "token_symbol" => "Air",
                 "tx_hash" => "th_2g1n8V2o5K5gw1aVX7PRz5nJbnrMQefLmE1WVVYsiFwwwU2fF5",
                 "tx_index" => 21_297_040,
                 "tx_type" => "contract_create_tx"
               }
             end)

      assert Enum.all?(response_list, fn %{"height" => height} -> height < kb_height end)

      assert length(response_list) == 6
    end
  end

  describe "balances/:contract_id" do
    test "gets all accounts balances for a contract", %{conn: conn} do
      contract_id = @big_balance_contract_id1
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts_map,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      Enum.each(amounts_map, fn {account, balance} ->
        assert String.starts_with?(account, "ak_")
        assert is_integer(balance) and balance >= 0
      end)
    end

    test "gets accounts balances for a contract with less than 100 amounts", %{conn: conn} do
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      assert is_map(amounts) and map_size(amounts) > 0 and map_size(amounts) < 100
    end

    test "gets balances for each contract", %{conn: conn} do
      aex9_pubkeys =
        Model.AexnContract
        |> Database.all_keys()
        |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)

      not_empty_balance_contracts =
        Enum.filter(aex9_pubkeys, fn {:aex9, contract_pk} ->
          contract_id = enc_ct(contract_pk)
          conn = get(conn, "/aex9/balances/#{contract_id}")

          assert %{
                   "amounts" => amounts,
                   "contract_id" => ^contract_id
                 } = json_response(conn, 200)

          assert is_map(amounts)

          map_size(amounts) > 0
        end)

      assert Enum.count(not_empty_balance_contracts) / Enum.count(aex9_pubkeys) > 0.95
    end

    test "returns the empty amounts for aex9 contract without balance", %{conn: conn} do
      contract_id = "ct_U7whpYJo4xXoXjEpw39mWEPKgKM2kgSZk9em5FLK8Xq2FrRWE"
      conn = get(conn, "/aex9/balances/#{contract_id}")

      assert %{
               "amounts" => amounts,
               "contract_id" => ^contract_id
             } = json_response(conn, 200)

      assert is_map(amounts) and map_size(amounts) == 0
    end
  end

  describe "balances/account/:account_id" do
    test "gets an account balances for multiple contracts", %{conn: conn} do
      account_id = "ak_WzcSck8B9ZPgHsy5XeqBbtUV4YbTuGyyJUzhSMvSK2JY1nzqJ"
      conn = get(conn, "/aex9/balances/account/#{account_id}")

      balances_response = json_response(conn, 200)

      assert Enum.any?(balances_response, fn %{"contract_id" => contract_id} ->
               contract_id == @big_balance_contract_id2
             end)

      Enum.each(balances_response, fn %{
                                        "contract_id" => contract_id,
                                        "token_name" => token_name,
                                        "token_symbol" => token_symbol
                                      } ->
        {:contract_pubkey, contract_pk} = :aeser_api_encoder.decode(contract_id)

        Model.aexn_contract(meta_info: {name, symbol, _decimals}) =
          Database.fetch!(Model.AexnContract, {:aex9, contract_pk})

        assert token_name == name
        assert token_symbol == symbol
      end)
    end

    @tag timeout: 60_000
    @tag :iteration
    test "gets balances for some accounts with aex9 presence", %{conn: conn} do
      state = State.new()

      account_ids =
        state
        |> Collection.stream(Model.Aex9AccountPresence, {nil, -1, nil})
        |> Enum.take(2_000)
        |> Enum.map(fn {account_pk, _txi, _contract_pk} ->
          :aeser_api_encoder.encode(:account_pubkey, account_pk)
        end)
        |> Enum.uniq()

      Enum.each(account_ids, fn account_id ->
        conn = get(conn, "/aex9/balances/account/#{account_id}")
        assert balances_response = json_response(conn, 200)

        Enum.each(balances_response, fn %{
                                          "contract_id" => contract_id,
                                          "token_name" => token_name,
                                          "token_symbol" => token_symbol
                                        } ->
          {:contract_pubkey, contract_pk} = :aeser_api_encoder.decode(contract_id)

          assert Model.aexn_contract(meta_info: {^token_name, ^token_symbol, _decimals}) =
                   Database.fetch!(Model.AexnContract, {:aex9, contract_pk})
        end)

        assert balances_response == Enum.dedup(balances_response)
      end)
    end

    test "gets balances for an account with mismatching aex9 presence", %{conn: conn} do
      state = State.new()

      prev_key =
        state
        |> Collection.stream(Model.Aex9AccountPresence, {nil, nil})
        |> Stream.take_while(fn {account_pk, contract_pk} ->
          :not_found != Database.fetch(Model.Aex9Balance, {contract_pk, account_pk})
        end)
        |> Enum.to_list()
        |> List.last()

      {:ok, {account_pk, _txi, contract_pk}} =
        Database.next_key(Model.Aex9AccountPresence, prev_key)

      assert :not_found = Database.fetch(Model.Aex9Balance, {contract_pk, account_pk})

      conn = get(conn, "/aex9/balances/account/#{enc_id(account_pk)}")
      assert balances_response = json_response(conn, 200)
      assert length(balances_response) > 0

      Enum.each(balances_response, fn %{
                                        "contract_id" => contract_id,
                                        "token_name" => token_name,
                                        "token_symbol" => token_symbol
                                      } ->
        {:contract_pubkey, contract_pk} = :aeser_api_encoder.decode(contract_id)

        assert Model.aexn_contract(meta_info: {^token_name, ^token_symbol, _decimals}) =
                 Database.fetch!(Model.AexnContract, {:aex9, contract_pk})
      end)
    end
  end

  describe "transfers from" do
    test "a sender paginated backwards with limit = 100", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      limit = 100

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated backwards with default limit", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated forward with limit = 100", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      limit = 100

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", limit: limit, direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a sender paginated forward with default limit", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from/#{account_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers to" do
    test "a recipient paginated backwards with limit = 100", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 50

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated backwards with default limit", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated forward with limit = 100", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 50

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", limit: limit, direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "a recipient paginated forward with default limit", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/to/#{account_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"recipient" => recipient_id} -> recipient_id == account_id end)
      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit
      assert next_uri2 != next_uri1 and String.contains?(next_uri2, account_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers from-to" do
    test "paginated backwards with limit = 100", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 30

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}", limit: limit)
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated backwards with default limit", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end, :desc)
      assert length(data2) == @default_limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated forward with limit = 100", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      limit = 30

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}",
          limit: limit,
          direction: "forward"
        )
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end

    test "paginated forward with default limit", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"

      %{"data" => data1, "next" => next_uri1} =
        conn
        |> get("/v2/aex9/transfers/from-to/#{from_id}/#{to_id}", direction: "forward")
        |> json_response(200)

      assert Enum.all?(data1, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data1 == Enum.sort_by(data1, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data1) == @default_limit

      %{"prev" => prev_uri, "data" => data2, "next" => next_uri2} =
        conn
        |> get(next_uri1)
        |> json_response(200)

      assert Enum.all?(data2, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data2 == Enum.sort_by(data2, fn %{"call_txi" => call_txi} -> call_txi end)
      assert length(data2) == @default_limit

      assert next_uri2 != next_uri1 and String.contains?(next_uri2, from_id) and
               String.contains?(next_uri2, to_id)

      assert %{"data" => ^data1, "next" => ^next_uri1} =
               conn
               |> get(prev_uri)
               |> json_response(200)
    end
  end

  describe "transfers_from_v1" do
    test "from a sender with many transfers", %{conn: conn} do
      account_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      conn = get(conn, "/aex9/transfers/from/#{account_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"sender" => sender_id} -> sender_id == account_id end)
      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end

  describe "transfers_to_v1" do
    test "to a recipient with many transfers", %{conn: conn} do
      account_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      conn = get(conn, "/aex9/transfers/to/#{account_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"recipient" => recipient_id} ->
               recipient_id == account_id
             end)

      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end

  describe "transfers_from_to_v1" do
    test "from a pair with many transfers", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      conn = get(conn, "/aex9/transfers/from-to/#{from_id}/#{to_id}")

      response = json_response(conn, 200)

      assert Enum.all?(response, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert response == Enum.sort_by(response, fn %{"call_txi" => call_txi} -> call_txi end)
    end
  end
end
