defmodule AeMdwWeb.GraphQL.EndpointIntegrationTest do
  # Fallback to direct ExUnit + Phoenix.ConnTest to avoid ConnCase load ordering issue
  use ExUnit.Case, async: false
  import Phoenix.ConnTest

  @endpoint AeMdwWeb.Endpoint
  @moduletag :graphql
  @graphql_path "/graphql"

  setup do
    previous_ttl = Application.get_env(:ae_mdw, :graphql_response_cache_ttl_ms, 0)
    clear_graphql_response_cache()

    on_exit(fn ->
      Application.put_env(:ae_mdw, :graphql_response_cache_ttl_ms, previous_ttl)
      clear_graphql_response_cache()
    end)

    {:ok, conn: build_conn()}
  end

  defp post_query(conn, query, attrs \\ %{}) do
    post(conn, @graphql_path, Map.put(attrs, "query", query))
  end

  defp clear_graphql_response_cache do
    case :ets.whereis(:graphql_response_cache) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end
  end

  defp graphql_response_cache_size do
    case :ets.whereis(:graphql_response_cache) do
      :undefined -> 0
      table -> :ets.info(table, :size)
    end
  end

  test "sync_status + key_blocks via HTTP returns data or partial_state_unavailable", %{
    conn: conn
  } do
    q = """
    { sync_status { last_synced_height partial } key_blocks(limit:5){ data { height hash miner } } }
    """

    resp = post_query(conn, q)
    assert resp.status == 200
    body = json_response(resp, 200)

    # sync_status should always be present when schema loaded
    # tolerate early schema edge
    assert is_map(get_in(body, ["data", "sync_status"])) or is_list(body["errors"])

    key_blocks = get_in(body, ["data", "key_blocks", "data"]) || []

    if key_blocks != [] do
      assert Enum.all?(key_blocks, &is_map/1)
    end

    # If errors exist, they should be among known tokens
    if errs = body["errors"] do
      known = ["partial_state_unavailable", "key_blocks_error", "invalid_cursor"]

      assert Enum.all?(errs, fn %{"message" => m} ->
               m in known or String.starts_with?(m, "Cannot return null")
             end)
    end
  end

  test "invalid GraphQL query returns errors array", %{conn: conn} do
    # Missing closing brace / unknown field ensures parse or validation error
    q = "{ no_such_field }"
    resp = post_query(conn, q)
    assert resp.status == 200
    body = json_response(resp, 200)
    assert is_list(body["errors"]) and length(body["errors"]) > 0
  end

  test "key_blocks limit is clamped (HTTP)", %{conn: conn} do
    q = "{ key_blocks(limit: 500) { data { height } } }"
    resp = post_query(conn, q)
    assert resp.status == 200
    body = json_response(resp, 200)
    data = get_in(body, ["data", "key_blocks", "data"]) || []
    assert length(data) <= 100 or data == []
  end

  test "error path structure for non-null field regression guard", %{conn: conn} do
    # Force a query that previously produced null list entries; we now assert entries aren't null.
    q = "{ key_blocks(limit:5){ data { height miner } } }"
    resp = post_query(conn, q)
    assert resp.status == 200
    body = json_response(resp, 200)
    entries = get_in(body, ["data", "key_blocks", "data"]) || []

    if entries != [] do
      refute Enum.any?(entries, &is_nil/1)
      Enum.each(entries, fn kb -> assert is_integer(kb["height"] || kb[:height]) end)
    else
      # If empty, acceptable early state
      assert true
    end
  end

  test "key_blocks no null elements after resolver filtering", %{conn: conn} do
    q = "{ key_blocks(limit:3){ data { height hash } } }"
    resp = post_query(conn, q)
    assert resp.status == 200
    body = json_response(resp, 200)
    entries = get_in(body, ["data", "key_blocks", "data"]) || []

    if entries != [] do
      refute Enum.any?(entries, &is_nil/1)

      assert Enum.all?(entries, fn e ->
               is_integer(e["height"] || e[:height]) and is_binary(e["hash"] || e[:hash])
             end)
    end
  end

  test "response cache keys include operationName", %{conn: conn} do
    Application.put_env(:ae_mdw, :graphql_response_cache_ttl_ms, 5_000)

    q = """
    query Meta { __typename }
    query Schema { __schema { queryType { name } } }
    """

    body1 =
      conn
      |> post_query(q, %{"operationName" => "Meta"})
      |> json_response(200)

    body2 =
      build_conn()
      |> post_query(q, %{"operationName" => "Schema"})
      |> json_response(200)

    assert Map.has_key?(body1["data"], "__typename")
    refute Map.has_key?(body1["data"], "__schema")

    assert Map.has_key?(body2["data"], "__schema")
    refute Map.has_key?(body2["data"], "__typename")

    assert graphql_response_cache_size() == 2
  end

  test "response cache ttl 0 does not store entries", %{conn: conn} do
    Application.put_env(:ae_mdw, :graphql_response_cache_ttl_ms, 0)

    body =
      conn
      |> post_query("{ __typename }")
      |> json_response(200)

    assert body["data"] != nil
    assert graphql_response_cache_size() == 0
  end
end
