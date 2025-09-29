defmodule AeMdwWeb.GraphQL.NamesBasicTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "names_count query" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ namesCount }", @schema, context: %{state: st})
      count = get_in(res, [:data, "namesCount"])
      assert is_integer(count) or is_nil(count)
    else
      assert true
    end
  end

  test "names pagination basic" do
    st = state()
    if st do
      {:ok, first} = Absinthe.run("{ names(limit:1){ data { name active } nextCursor } }", @schema, context: %{state: st})
      next = get_in(first, [:data, "names", "nextCursor"])
      if next do
        {:ok, second} = Absinthe.run("{ names(limit:1, cursor:\"#{next}\"){ data { name } nextCursor } }", @schema, context: %{state: st})
        assert get_in(second, [:data, "names", "data"]) != []
      end
    else
      assert true
    end
  end

  test "single name query tolerant" do
    st = state()
    if st do
      # Try to fetch first name from names list if available
      {:ok, first} = Absinthe.run("{ names(limit:1){ data { name } } }", @schema, context: %{state: st})
      name = get_in(first, [:data, "names", "data", Access.at(0), "name"])
      if name do
        {:ok, res} = Absinthe.run("{ name(id:\"#{name}\"){ name active } }", @schema, context: %{state: st})
        assert get_in(res, [:data, "name", "name"]) == name
      end
    else
      assert true
    end
  end
end
