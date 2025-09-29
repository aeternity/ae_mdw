defmodule AeMdwWeb.GraphQL.BlockQueriesTest do
  use ExUnit.Case, async: false

  @moduletag :graphql

  @schema AeMdwWeb.GraphQL.Schema

  test "key_blocks basic pagination returns structure" do
    query = """
    { keyBlocks: key_blocks(limit: 1) { prevCursor nextCursor data { height hash } } }
    """
    # We rely on real state; skip if no state available
    case Absinthe.run(query, @schema, context: %{}) do
      {:ok, %{errors: [%{message: "missing_state"}|_]}} ->
        assert true
      {:ok, %{data: %{"keyBlocks" => page}}} ->
        assert Map.has_key?(page, "data")
      other -> flunk("unexpected: #{inspect(other)}")
    end
  end

  test "invalid cursor returns error" do
    query = "{ key_blocks(cursor: \"bad!\") { nextCursor } }"
    # Provide an empty context; resolver will short-circuit invalid cursor even without state
    {:ok, result} = Absinthe.run(query, @schema, context: %{})
    assert Enum.any?(result.errors, &match?(%{message: "invalid_cursor"}, &1))
  end
end
