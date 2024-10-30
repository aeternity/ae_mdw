defmodule Integration.AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase, async: false
  use Mneme

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Validate

  require Model

  @moduletag :integration

  @big_balance_contract_id1 "ct_BwJcRRa7jTAvkpzc2D16tJzHMGCJurtJMUBtyyfGi2QjPuMVv"
  @big_balance_contract_id2 "ct_uGk1rkSdccPKXLzS259vdrJGTWAY9sfgVYspv6QYomxvWZWBM"
  @big_balance_contract_id3 "ct_M9yohHgcLjhpp1Z8SaA1UTmRMQzR4FWjJHajGga8KBoZTEPwC"

  @default_limit 10

  describe "by_contract" do
    test "gets an aex9 token by contract id", %{conn: conn} do
      contract_id = "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt"

      auto_assert(
        %{
          "contract_id" => ^contract_id,
          "contract_tx_hash" => "th_2r5gAptR7prYmXUgiRZXVDUvxuJ5PYe94vqviWh77bCzQRcCko",
          "decimals" => 18,
          "event_supply" => 10_000_000_000_000_000_000_000_000_000_000_000_000,
          "extensions" => ["allowances", "mintable", "burnable", "swappable"],
          "holders" => 1,
          "initial_supply" => 10_000_000_000_000_000_000_000_000_000_000_000_000,
          "invalid" => false,
          "logs_count" => 0,
          "name" => "9GAG",
          "symbol" => "9GAG"
        } <-
          conn
          |> get("/v3/aex9/#{contract_id}")
          |> json_response(200)
      )

      contract_id = "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer"

      auto_assert(
        %{
          "contract_id" => ^contract_id,
          "contract_tx_hash" => "th_2EdQvcFbKXj4ee1ph3i4QnK2U4FBeYdVRMi47vtDWc1KvET7Bh",
          "decimals" => 18,
          "event_supply" => 1_000_000_000_000_000_000,
          "extensions" => [],
          "holders" => 1,
          "initial_supply" => 1_000_000_000_000_000_000,
          "invalid" => false,
          "logs_count" => 0,
          "name" => "AAA",
          "symbol" => "AAA"
        } <-
          conn
          |> get("/v3/aex9/#{contract_id}")
          |> json_response(200)
      )

      # WAE contract
      contract_id = "ct_J3zBY8xxjsRr3QojETNw48Eb38fjvEuJKkQ6KzECvubvEcvCa"

      auto_assert(
        %{
          "contract_id" => ^contract_id,
          "contract_tx_hash" => "th_2w36BEYthD48fmveWrHLvzYpyKeTHtWLXCSqLEQjiSFARGfdaM",
          "decimals" => 18,
          "event_supply" => 32_067_122_530_333_274_155_599,
          "extensions" => ["allowances"],
          "holders" => _holders,
          "initial_supply" => 0,
          "invalid" => false,
          "logs_count" => _logs_count,
          "name" => "aeWrapped Aeternity",
          "symbol" => "aeWAE"
        } <-
          conn
          |> get("/v3/aex9/#{contract_id}")
          |> json_response(200)
      )
    end

    @tag :iteration
    test "gets each of the aex9 tokens by contract id", %{conn: conn} do
      Model.AexnContract
      |> Database.all_keys()
      |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)
      |> Enum.reject(fn index -> Database.exists?(Model.AexnInvalidContract, index) end)
      |> Enum.each(fn {:aex9, aex9_pubkey} ->
        contract_id = encode_contract(aex9_pubkey)

        %{
          "contract_id" => ^contract_id,
          "contract_tx_hash" => _contract_tx_hash,
          "decimals" => decimals,
          "event_supply" => _event_supply,
          "extensions" => _extensions,
          "holders" => _holders,
          "initial_supply" => _initial_supply,
          "logs_count" => _logs_count,
          "name" => name,
          "symbol" => symbol
        } =
          conn
          |> get("/v3/aex9/#{contract_id}")
          |> json_response(200)

        assert is_binary(name)
        assert is_binary(symbol)

        if name in ["format_error", "out_of_gas_error"] do
          assert is_nil(decimals)
        else
          assert is_integer(decimals) and decimals >= 0
        end
      end)
    end
  end

  describe "by_name" do
    test "gets aex9 tokens sorted by name", %{conn: conn} do
      auto_assert(
        %{
          "data" => [
            %{
              "contract_id" => "ct_x8NeGisMer3sQUWJUa4J2QnfMKRPCLcpUja84noQfWcEd8qma",
              "contract_tx_hash" => "th_fknbs1yWTJJbX8RZgpfQdiRE8JoU13dgBE2HHcz4WaJkmwYdp",
              "decimals" => 18,
              "event_supply" => 100_000_000_000_000_000_000,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 3,
              "initial_supply" => 100_000_000_000_000_000_000,
              "invalid" => false,
              "logs_count" => 16,
              "name" => "100",
              "symbol" => "100"
            },
            %{
              "contract_id" => "ct_EoS1dkrxjDWEL9h6GSJ6HXTL5UMckfey7wdwPQPFKHm2TYr8d",
              "contract_tx_hash" => "th_Hsx7pXeu24BoKYqcpnENS7TfD8vhiTiZWRwvXgLXXHTpk9cyH",
              "decimals" => 18,
              "event_supply" => 1_000_000_000_000_000_000_000,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 3,
              "initial_supply" => 1_000_000_000_000_000_000_000,
              "invalid" => false,
              "logs_count" => 6,
              "name" => "1000",
              "symbol" => "1000"
            },
            %{
              "contract_id" => "ct_jLDTvTpNXNrUz6GxTyNaH2A7NmtGejACLszyLtT6BkZpjcVCp",
              "contract_tx_hash" => "th_pmswZYbCPi5xJ3iuamRwDB2Jjj85n5K7HQRWZ7W3g1BNUPdV7",
              "decimals" => 18,
              "event_supply" => 10_890_000_000_000_000_000,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 4,
              "initial_supply" => 10_000_000_000_000_000_000,
              "invalid" => false,
              "logs_count" => 21,
              "name" => "100DAYS",
              "symbol" => "100DAYS"
            }
          ],
          "next" =>
            "/v3/aex9?by=name&cursor=g2gDdwRhZXg5bQAAAAsxaW5jaCB0b2tlbm0AAAAg0V2fL1aX22vZGizsDW%2FMVgmD4Lz9NJdWhhXljlcMjOs&direction=forward&limit=3",
          "prev" => nil
        } <-
          conn
          |> get("/v3/aex9", by: "name", direction: "forward", limit: 3)
          |> json_response(200)
      )
    end
  end

  describe "by_symbol" do
    test "gets aex9 tokens sorted by symbol", %{conn: conn} do
      auto_assert(
        %{
          "data" => [
            %{
              "contract_id" => "ct_TEt8raHSNKZWHNN8TaCvV2VKDuSGPcxAZhNJcq62M8Gwp6zM9",
              "contract_tx_hash" => "th_rbFNrRDpn6finytCEmHAExtBnRxt14yckvuCWRmXxsRpypHxt",
              "decimals" => 18,
              "event_supply" => 99_000_000_000_000_000_000,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 2,
              "initial_supply" => 99_000_000_000_000_000_000,
              "invalid" => false,
              "logs_count" => 2,
              "name" => "🚀",
              "symbol" => "🚀"
            },
            %{
              "contract_id" => "ct_2c9FiRkUw82UQNNsZX2rZpyuMbXq2n8mbcHUmJhw4coAxTMSKL",
              "contract_tx_hash" => "th_Bn7FJsvErm4NDg5EzQLaxNPXFnwZAcDH7f1ESWfXJzcRh3HQo",
              "decimals" => 18,
              "event_supply" => 123_456_789,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 1,
              "initial_supply" => 123_456_789,
              "invalid" => false,
              "logs_count" => 0,
              "name" => "🔥",
              "symbol" => "🔥"
            },
            %{
              "contract_id" => "ct_2gcT1A6Rta95vVkw9x5vgDE2VxPB8PV8pyUE9SRKutHJCzZYeH",
              "contract_tx_hash" => "th_KmYmiKdDZ6pFqvzKMrJMMfqHpDbDMGdkAgVxsSSTCXUm2jdzF",
              "decimals" => 18,
              "event_supply" => 123_000_000_000_000_000_000,
              "extensions" => ["allowances", "mintable", "burnable", "swappable"],
              "holders" => 2,
              "initial_supply" => 123_000_000_000_000_000_000,
              "invalid" => false,
              "logs_count" => 1,
              "name" => "👀",
              "symbol" => "👀"
            }
          ],
          "next" =>
            "/v3/aex9?by=symbol&cursor=g2gDdwRhZXg5bQAAAAbinaTvuI9tAAAAII2HYRV%2FASqPiNMi9ZVlJxxcifVMw%2FmuN%2BmO875INDpD&limit=3",
          "prev" => nil
        } <-
          conn
          |> get("/v3/aex9", by: "symbol", limit: 3)
          |> json_response(200)
      )
    end
  end

  describe "balance_range" do
    test "gets account balance on a contract for range of generations", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      account_id = "ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"
      first = 489_501
      last = 489_510

      auto_assert(
        %{
          "data" => [
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => ^first
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_502
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_503
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_504
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_505
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_506
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_507
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_045,
              "contract" => ^contract_id,
              "height" => 489_508
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_135,
              "contract" => ^contract_id,
              "height" => 489_509
            },
            %{
              "account" => ^account_id,
              "amount" => 9_975_135,
              "contract" => ^contract_id,
              "height" => ^last
            }
          ],
          "next" => nil,
          "prev" => nil
        } <-
          conn
          |> get("/v3/aex9/#{contract_id}/balances/#{account_id}/history",
            scope: "gen:#{first}-#{last}"
          )
          |> json_response(200)
      )
    end

    test "returns zero results if contract had not been created up to the block", %{conn: conn} do
      contract_id = "ct_2t7TnocFw7oCYSS7g2yGutZMpGEJta6dq2DTX38SmuqmwtN6Ch"
      account_id = "ak_psy8tRXPzGxh6975H7K6XQcMFVsdrxJMt7YkzMY8oUTevutzw"
      first = 487_100
      last = 487_100

      auto_assert(
        %{"data" => [], "next" => nil, "prev" => nil} <-
          conn
          |> get("/v3/aex9/#{contract_id}/balances/#{account_id}/history",
            scope: "gen:#{first}-#{last}"
          )
          |> json_response(200)
      )
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
      |> Enum.filter(fn {type, contract_pk} ->
        type == :aex9 &&
          Origin.tx_index!(state, {:contract, contract_pk}) < range_txi and
          encode_contract(contract_pk) not in [
            @big_balance_contract_id1,
            @big_balance_contract_id2,
            @big_balance_contract_id3
          ]
      end)
      |> Enum.each(fn {:aex9, aex9_pubkey} ->
        contract_id = encode_contract(aex9_pubkey)

        %{"data" => data} =
          conn
          |> get("/v3/aex9/#{contract_id}/balances", scope: "gen:#{first}-#{last}")
          |> json_response(200)

        data
        |> Enum.zip(first..last)
        |> Enum.each(fn {height_map, height} ->
          assert %{
                   "amounts" => amounts,
                   "block_hash" => hash,
                   "height" => ^height,
                   "contract_id" => ^contract_id
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
      conn = get(conn, "/v3/aex9/#{contract_id}/balances", block_hash: mb_hash)

      auto_assert(
        %{
          "data" => [
            %{
              "account_id" => "ak_2Xu6d6W4UJBWyvBVJQRHASbQHQ1vjBA7d1XUeY8SwwgzssZVHK",
              "amount" => 8_100_000_000_000,
              "block_hash" => "mh_2TwVRHgyXpQpjT5Z44BJQexijf6rtweypDGK3mtCZWnBFGxTV7",
              "contract_id" => ^contract_id,
              "height" => 335_293,
              "last_log_idx" => 1,
              "last_tx_hash" => "th_YkRFtLNgT9eZqfuFAihSt14L1GCHxiNSS44h2B5wiNSfvBSc5"
            },
            %{
              "account_id" => "ak_2MHJv6JcdcfpNvu4wRDZXWzq8QSxGbhUfhMLR7vUPzRFYsDFw6",
              "amount" => 4_050_000_000_000,
              "block_hash" => "mh_2TwVRHgyXpQpjT5Z44BJQexijf6rtweypDGK3mtCZWnBFGxTV7",
              "contract_id" => ^contract_id,
              "height" => 335_293,
              "last_log_idx" => 2,
              "last_tx_hash" => "th_YkRFtLNgT9eZqfuFAihSt14L1GCHxiNSS44h2B5wiNSfvBSc5"
            },
            %{
              "account_id" => "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
              "amount" => 49_999_999_999_906_850_000_000_000,
              "block_hash" => "mh_2TwVRHgyXpQpjT5Z44BJQexijf6rtweypDGK3mtCZWnBFGxTV7",
              "contract_id" => ^contract_id,
              "height" => 335_293,
              "last_log_idx" => 2,
              "last_tx_hash" => "th_YkRFtLNgT9eZqfuFAihSt14L1GCHxiNSS44h2B5wiNSfvBSc5"
            },
            %{
              "account_id" => "ak_CNcf2oywqbgmVg3FfKdbHQJfB959wrVwqfzSpdWVKZnep7nj4",
              "amount" => 81_000_000_000_000,
              "block_hash" => "mh_2TwVRHgyXpQpjT5Z44BJQexijf6rtweypDGK3mtCZWnBFGxTV7",
              "contract_id" => ^contract_id,
              "height" => 335_293,
              "last_log_idx" => 0,
              "last_tx_hash" => "th_YkRFtLNgT9eZqfuFAihSt14L1GCHxiNSS44h2B5wiNSfvBSc5"
            }
          ],
          "next" => nil,
          "prev" => nil
        } <- json_response(conn, 200)
      )
    end

    test "returns 404 if contract had not been created up to the block", %{conn: conn} do
      hash = "kh_NM2cxdzg6mf4KMFMXw1kAzBJGwFoqiGHQtaKx3DvaAGM5CAkn"
      contract_id = "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      conn = get(conn, "/v3/aex9/#{contract_id}/balances", block_hash: hash)

      assert %{"error" => error} = json_response(conn, 404)
      assert error == "not found: #{contract_id}"
    end

    @tag :iteration
    test "gets balances for some hashes and each contract", %{conn: conn} do
      mb_hashes =
        [
          {700_001, 1},
          {1000_002, 2},
          {1000_003, 3}
        ]
        |> Enum.map(&Database.fetch!(Model.Block, &1))
        |> Enum.map(fn Model.block(tx_index: txi, hash: mb_hash) ->
          {txi, :aeser_api_encoder.encode(:micro_block_hash, mb_hash)}
        end)

      state = State.new()

      Model.AexnContract
      |> Database.all_keys()
      |> Enum.filter(fn {type, _pubkey} -> type == :aex9 end)
      |> Enum.map(fn {:aex9, ct_pk} -> encode_contract(ct_pk) end)
      |> Enum.zip(mb_hashes)
      |> Enum.filter(fn {contract_id, {mb_txi, _mb_hash}} ->
        ct_pk = Validate.id!(contract_id)
        Origin.tx_index!(state, {:contract, ct_pk}) > mb_txi
      end)
      |> Enum.each(fn {contract_id, {_mb_txi, mb_hash}} ->
        conn = get(conn, "/v3/aex9/#{contract_id}/balances", block_hash: mb_hash)

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
      conn = get(conn, "/aex9/balances/account/#{account_id}", blockhash: mb_hash)

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
      conn = get(conn, "/aex9/balances/account/#{account_id}", height: kb_height)

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
      aex9_pubkeys = [
        "ct_2TZsPKT5wyahqFrzp8YX7DfXQapQ4Qk65yn3sHbifU9Db9hoav",
        "ct_1DtebWK23btGPEnfiH3fxppd34S75uUryo5yGmb938Dx9Nyjt",
        "ct_7HD1qro97784gEPA22HuXqn328XFsWzdTM6ELzSNTRSFmeXrv",
        "ct_8SnTpFBAxZD7WbUN1bXqSoa2Zgf4M4L2GLGY2Vkosr5jHtfVe",
        "ct_96zkVfzSqnAqT3BKJMDNc3oiYhNUJbsMorSJhyp9xaUUKVFSh",
        "ct_AdhAL6YZ2wZKKTcR8Gf8CYSGsWC1siWNyv8JRvRpB3RbeAwer",
        "ct_Frcy81aKCkd5HZLjtxkLFtN27xCRsvn1LgfVfNwtDN2YnSdHP",
        "ct_GEwAb3denzg7uTVSkjvevGrXGtt7cgBencMByscEzjJBUwS4x",
        "ct_GKZosdCRANTixw4DZvQBn72DbxsAVGNWjShLzBspjNAWCqjks",
        "ct_GVVWFC6i62RrWHAkez1EweAAthJsgiCqp8gmQ3rhb3zpi1dF8",
        "ct_HEsvfAUzHe4eAaVwG6rzaoQWrKMz2bT1CuocdztAL5oPhzDpG",
        "ct_JehCZkTbiTVoPHd42DuPqtCv3pprtmpSv2W5LfLgHBZWvWqr5",
        "ct_RHiPRbJH3N8QhUGhXUoKofJcH53FbmkPZxkpdkhp1RpHqBwNw",
        "ct_UzvRD43yuKTpmytYZbzUieLvxXB2FQvSAMf14H3Rz6DThupCn",
        "ct_bvRK5CdQKoqswFZskioS6tu5Z1CBhSmD3zyiqrLFHv1pV81EQ",
        "ct_hNZmPkHTtGJJXqaV4kb4JcmhMQdGdvef91g4Ck9BVqWKkT8xd",
        "ct_icxpMgSrVb4xJkieSQRu5iBcP6CqbRrpGTNt99DfwyRz5Ly7h",
        "ct_ipFbBQasdRJ6KkzFKvUn5oaXpC147qqRM1NarMCkmYtHdd2cJ",
        "ct_pd1SeSAvF9CUcbd8cABYWfEbWygW5ja74gJYi1QFJtqCD4a22",
        "ct_sMVni6coWLTMkHY4Si9jthm2RVqRpXe7cPRMVj2T9YJBW4tA9"
      ]

      not_empty_balance_contracts =
        Enum.filter(aex9_pubkeys, fn contract_id ->
          assert %{
                   "amounts" => amounts,
                   "contract_id" => ^contract_id
                 } =
                   conn
                   |> get("/aex9/balances/#{contract_id}")
                   |> json_response(200)

          assert is_map(amounts)

          map_size(amounts) > 0
        end)

      assert Enum.count(not_empty_balance_contracts) / Enum.count(aex9_pubkeys) > 0.95
    end

    test "returns the empty amounts for aex9 contract without balance", %{conn: conn} do
      contract_id = "ct_U7whpYJo4xXoXjEpw39mWEPKgKM2kgSZk9em5FLK8Xq2FrRWE"
      conn = get(conn, "/v3/aex9/#{contract_id}/balances")

      assert %{"data" => []} = json_response(conn, 200)
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
      account_ids = [
        "ak_11111111111111111111111111111111273Yts",
        "ak_115zZ7bGVVkqLJesUmxScgPKpEikT5YCmQ4PQe2uJ4qS4Hcs1",
        "ak_18GcdZmEP8NgLWke2fsdP6fryrrcu4xSpiGa49w6aMWfrC2Y",
        "ak_19b25xw5MLVe3aAnwXYmf7LXxhUaSay6fK3yBaKqiMyDyv9C"
      ]

      Enum.each(account_ids, fn account_id ->
        balances_response =
          conn
          |> get("/aex9/balances/account/#{account_id}")
          |> json_response(200)

        Enum.each(balances_response, fn %{
                                          "contract_id" => contract_id,
                                          "token_name" => token_name,
                                          "token_symbol" => token_symbol
                                        }
                                        when is_binary(token_name) and is_binary(token_symbol) ->
          {:contract_pubkey, _contract_pk} = :aeser_api_encoder.decode(contract_id)
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
          :not_found != Database.fetch(Model.Aex9EventBalance, {contract_pk, account_pk})
        end)
        |> Enum.to_list()
        |> List.last()

      with {:ok, {account_pk, _txi, contract_pk}} <-
             Database.next_key(Model.Aex9AccountPresence, prev_key) do
        assert :not_found = Database.fetch(Model.Aex9EventBalance, {contract_pk, account_pk})

        conn = get(conn, "/aex9/balances/account/#{encode_account(account_pk)}")
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

  describe "transfers_from_to_v2" do
    test "from a pair with many transfers", %{conn: conn} do
      from_id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"
      to_id = "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
      conn = get(conn, "/v2/aex9/transfers/from-to/#{from_id}/#{to_id}")

      %{"data" => data} = json_response(conn, 200)

      assert Enum.all?(data, fn %{"sender" => sender_id, "recipient" => recipient_id} ->
               sender_id == from_id and recipient_id == to_id
             end)

      assert data == Enum.sort_by(data, fn %{"call_txi" => call_txi} -> call_txi end, &>=/2)
    end
  end
end
