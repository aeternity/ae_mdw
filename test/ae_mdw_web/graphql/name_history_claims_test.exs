defmodule AeMdwWeb.GraphQL.NameHistoryClaimsTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp first_name(st) do
    {:ok, res} = Absinthe.run("{ names(limit:1){ data { name } } }", @schema, context: %{state: st})
    get_in(res, [:data, "names", "data", Access.at(0), "name"])
  end

  test "name history basic" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, res} = Absinthe.run("{ nameHistory(id:\"#{name}\", limit:5){ data { height sourceTxHash } nextCursor } }", @schema, context: %{state: st})
          _ = get_in(res, [:data, "nameHistory", "data"])
          assert Map.get(res, :errors, []) == []
        end
    else
      assert true
    end
  end

  test "name claims basic" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, res} = Absinthe.run("{ nameClaims(id:\"#{name}\", limit:3){ data { sourceTxType } nextCursor } }", @schema, context: %{state: st})
          _ = get_in(res, [:data, "nameClaims", "data"])
          assert Map.get(res, :errors, []) == []
      end
    else
      assert true
    end
  end
end
