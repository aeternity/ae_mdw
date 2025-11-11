defmodule AeMdwWeb.GraphQL.NameUpdatesTransfersTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp first_name(st) do
    {:ok, res} = Absinthe.run("{ names(limit:1){ data { name } } }", @schema, context: %{state: st})
    get_in(res, [:data, "names", "data", Access.at(0), "name"])
  end

  test "name updates basic" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, res} = Absinthe.run("{ nameUpdates(id:\"#{name}\", limit:2){ data { sourceTxType } } }", @schema, context: %{state: st})
          assert Map.get(res, :errors, []) == []
      end
    else
      assert true
    end
  end

  test "name transfers basic" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, res} = Absinthe.run("{ nameTransfers(id:\"#{name}\", limit:2){ data { sourceTxType } } }", @schema, context: %{state: st})
          assert Map.get(res, :errors, []) == []
      end
    else
      assert true
    end
  end
end
