defmodule AeMdwWeb.GraphQL.PointeesTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "account pointees basic" do
    st = state()

    if st do
      {:ok, accs} =
        Absinthe.run("{ accounts(limit:1){ data { id } } }", @schema, context: %{state: st})

      id = get_in(accs, [:data, "accounts", "data", Access.at(0), "id"])

      if id do
        {:ok, res} =
          Absinthe.run("{ accountPointees(id:\"#{id}\", limit:1){ data { name key } } }", @schema,
            context: %{state: st}
          )

        assert Map.get(res, :errors, []) == []
      end
    else
      assert true
    end
  end

  test "name pointers basic" do
    st = state()

    if st do
      {:ok, names} =
        Absinthe.run("{ names(limit:1){ data { name hash } } }", @schema, context: %{state: st})

      name = get_in(names, [:data, "names", "data", Access.at(0), "name"])

      if name do
          if name do
          {:ok, res2} =
              Absinthe.run("{ name(id:\"#{name}\"){ pointers } }", @schema,
              context: %{state: st}
            )

          assert Map.get(res2, :errors, []) == []
          _ = get_in(res2, [:data, "name", "pointers"])
        end
      end
    else
      assert true
    end
  end
end
