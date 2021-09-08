defmodule AeMdwWeb.OracleControllerTest do
  use AeMdwWeb.ConnCase, async: false

  import Mock

  require AeMdw.Db.Model

  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.ActiveOracleExpiration
  # alias AeMdw.Db.Model.ActiveOracle
  alias AeMdw.Db.Model.Block
  alias AeMdw.Db.Oracle
  alias AeMdw.Mnesia
  alias AeMdw.TestSamples, as: TS

  describe "active_oracles_v2" do
    test "it retrieves all active oracles backwards by default", %{conn: conn} do
      next_cursor = nil
      expiration_keys = [TS.oracle_expiration_key(1), TS.oracle_expiration_key(2)]
      Model.oracle(index: pk) = oracle = TS.oracle()
      encoded_pk = :aeser_api_encoder.encode(:oracle_pubkey, pk)

      with_mocks [
        {Mnesia, [],
         [
           fetch_keys: fn _tab, _dir, _cursor, _limit -> {expiration_keys, next_cursor} end,
           last_key: fn Block -> {:ok, TS.last_gen()} end,
           fetch!: fn _tab, _oracle_pk -> oracle end
         ]},
        {Oracle, [], [oracle_tree!: fn _bi -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]}
      ] do
        assert %{"data" => [oracle1, _oracle2], "next" => nil} =
                 conn
                 |> get("/v2/oracles/active")
                 |> json_response(200)

        assert %{"oracle" => ^encoded_pk} = oracle1

        assert_called(Mnesia.fetch_keys(ActiveOracleExpiration, :backward, nil, 10))
        assert_called(Mnesia.last_key(Block))
      end
    end

    test "it provides a 'next' cursor when more than limit of 10", %{conn: conn} do
      next_cursor = {next_cursor_exp, next_cursor_pk} = TS.oracle_expiration_key(0)
      next_cursor_pk_encoded = :aeser_api_encoder.encode(:oracle_pubkey, next_cursor_pk)
      next_cursor_query_value = "#{next_cursor_exp}-#{next_cursor_pk_encoded}"
      expiration_keys = 0..4 |> Enum.map(fn n -> TS.oracle_expiration_key(n) end)

      with_mocks [
        {Mnesia, [],
         [
           fetch_keys: fn _tab, _dir, _cursor, _limit -> {expiration_keys, next_cursor} end,
           last_key: fn Block -> {:ok, TS.last_gen()} end,
           fetch!: fn _tab, _oracle_pk -> TS.oracle() end
         ]},
        {Oracle, [], [oracle_tree!: fn _bi -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]}
      ] do
        assert %{"next" => next_uri} = conn |> get("/v2/oracles/active") |> json_response(200)

        assert %URI{
                 path: "/v2/oracles/active/backward",
                 query: query
               } = URI.parse(next_uri)

        assert %{"cursor" => ^next_cursor_query_value} = URI.decode_query(query)

        assert_called(Mnesia.fetch_keys(ActiveOracleExpiration, :backward, nil, 10))
      end
    end
  end
end
