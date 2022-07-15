defmodule AeMdwWeb.OracleControllerTest do
  use AeMdwWeb.ConnCase, async: false

  import Mock

  require AeMdw.Db.Model

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.ActiveOracleExpiration
  alias AeMdw.Db.Model.InactiveOracleExpiration
  alias AeMdw.Db.Model.Block
  alias AeMdw.Db.Oracle
  alias AeMdw.Database
  alias AeMdw.TestSamples, as: TS

  describe "oracles" do
    test "it retrieves active oracles first", %{conn: conn} do
      Model.oracle(index: pk) = oracle = TS.oracle()
      encoded_pk = :aeser_api_encoder.encode(:oracle_pubkey, pk)
      last_gen = TS.last_gen()

      with_mocks [
        {Database, [],
         [
           prev_key: fn ActiveOracleExpiration, {exp, plain_name} ->
             {:ok, {exp - 1, "a#{plain_name}"}}
           end,
           last_key: fn
             Block -> {:ok, last_gen}
             ActiveOracleExpiration -> {:ok, TS.oracle_expiration_key(1)}
             InactiveOracleExpiration -> :none
           end,
           get: fn
             Model.ActiveOracle, _pk -> {:ok, oracle}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash())}
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]}
      ] do
        assert %{"data" => [oracle1 | _rest] = oracles, "next" => next_uri} =
                 conn
                 |> get("/oracles")
                 |> json_response(200)

        assert 10 = length(oracles)
        assert %{"oracle" => ^encoded_pk} = oracle1

        assert %URI{
                 path: "/oracles",
                 query: query
               } = URI.parse(next_uri)
      end
    end

    test "it retrieves both active and inactive when length(active) < limit", %{conn: conn} do
      Model.oracle(index: pk) = oracle = TS.oracle()
      encoded_pk = :aeser_api_encoder.encode(:oracle_pubkey, pk)

      with_mocks [
        {Database, [],
         [
           next_key: fn _tab, _key -> :none end,
           prev_key: fn
             ActiveOracleExpiration, {0, _plain_name} -> :none
             ActiveOracleExpiration, {exp, "a"} -> {:ok, {exp - 1, "a"}}
             InactiveOracleExpiration, {0, "b"} -> :none
             InactiveOracleExpiration, {exp, "b"} -> {:ok, {exp - 1, "b"}}
           end,
           last_key: fn
             Block -> {:ok, TS.last_gen()}
             ActiveOracleExpiration -> {:ok, {1, "a"}}
             InactiveOracleExpiration -> {:ok, {1, "b"}}
           end,
           get: fn
             Model.InactiveOracle, _oracle_pk -> {:ok, oracle}
             Model.ActiveOracle, _oracle_pk -> {:ok, oracle}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash())}
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]}
      ] do
        assert %{"data" => [oracle1, _oracle2, _oracle3, _oracle4], "next" => nil} =
                 conn
                 |> get("/oracles")
                 |> json_response(200)

        assert %{"oracle" => ^encoded_pk} = oracle1
      end
    end
  end

  describe "active_oracles" do
    test "it retrieves all active oracles backwards by default", %{conn: conn} do
      key1 = TS.oracle_expiration_key(1)
      key2 = TS.oracle_expiration_key(2)
      Model.oracle(index: pk) = oracle = TS.oracle()
      encoded_pk = :aeser_api_encoder.encode(:oracle_pubkey, pk)

      with_mocks [
        {Database, [],
         [
           last_key: fn
             Block -> {:ok, TS.last_gen()}
             ActiveOracleExpiration -> {:ok, key1}
           end,
           get: fn
             Model.ActiveOracle, _oracle_pk -> {:ok, oracle}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash())}
           end,
           next_key: fn _tab, _key -> :none end,
           prev_key: fn
             _tab, ^key1 -> {:ok, key2}
             _tab, ^key2 -> :none
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]}
      ] do
        assert %{"data" => [oracle1, _oracle2], "next" => nil} =
                 conn
                 |> get("/oracles/active")
                 |> json_response(200)

        assert %{"oracle" => ^encoded_pk} = oracle1

        assert_called(Database.last_key(Block))
      end
    end

    test "it provides a 'next' cursor when more than limit of 10", %{conn: conn} do
      expiration_key = {next_cursor_exp, next_cursor_pk} = TS.oracle_expiration_key(0)
      next_cursor_pk_encoded = :aeser_api_encoder.encode(:oracle_pubkey, next_cursor_pk)
      next_cursor_query_value = "#{next_cursor_exp}-#{next_cursor_pk_encoded}"

      with_mocks [
        {Database, [],
         [
           last_key: fn
             Block -> {:ok, TS.last_gen()}
             ActiveOracleExpiration -> {:ok, expiration_key}
           end,
           next_key: fn ActiveOracleExpiration, _key -> {:ok, expiration_key} end,
           prev_key: fn ActiveOracleExpiration, _key -> {:ok, expiration_key} end,
           get: fn
             Model.ActiveOracle, _oracle_pk -> {:ok, TS.oracle()}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash())}
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]}
      ] do
        assert %{"next" => next_uri} = conn |> get("/oracles/active") |> json_response(200)

        assert %URI{
                 path: "/oracles/active",
                 query: query
               } = URI.parse(next_uri)

        assert %{"cursor" => ^next_cursor_query_value} = URI.decode_query(query)
      end
    end
  end
end
