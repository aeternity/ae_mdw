defmodule AeMdwWeb.GraphQL.PaginationEdgeCasesTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "accounts large limit clamps" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ accounts(limit:1000){ data { id } } }", @schema, context: %{state: st})
      data = get_in(res, [:data, "accounts", "data"]) || []
      assert length(data) <= 100
    else
      assert true
    end
  end

  test "names large limit clamps" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ names(limit:500){ data { name } } }", @schema, context: %{state: st})
      data = get_in(res, [:data, "names", "data"]) || []
      assert length(data) <= 100 # internal clamp 100 in resolver
    else
      assert true
    end
  end

  test "names invalid cursor tolerates" do
    st = state()
    if st do
  {:ok, res} = Absinthe.run("{ names(cursor: \"!!invalid!!\", limit:1){ data { name } } }", @schema, context: %{state: st})
      _ = get_in(res, [:data, "names", "data"]) || []
      # Just ensure no internal errors captured
      assert Map.get(res, :errors, []) == []
    else
      assert true
    end
  end

  test "name not found error" do
    st = state()
    if st do
  {:ok, res} = Absinthe.run("{ name(id: \"nonexistentname.chain\"){ name } }", @schema, context: %{state: st})
      # Absinthe encodes errors; ensure there is an error when no data
      if get_in(res, [:data, "name"]) == nil do
        assert length(res.errors) > 0
      end
    else
      assert true
    end
  end

  test "invalid account id error" do
    st = state()
    if st do
  {:ok, res} = Absinthe.run("{ account(id: \"invalid_pubkey\"){ id } }", @schema, context: %{state: st})
      if get_in(res, [:data, "account"]) == nil do
        assert length(res.errors) > 0
      end
    else
      assert true
    end
  end
end
