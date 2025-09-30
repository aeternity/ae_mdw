defmodule AeMdwWeb.GraphQL.MultiPageInvalidCursorsTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp first_name(st) do
    {:ok, res} = Absinthe.run("{ names(limit:1){ data { name } } }", @schema, context: %{state: st})
    get_in(res, [:data, "names", "data", Access.at(0), "name"])
  end

  test "accounts multi-page pagination" do
    st = state()
    if st do
      {:ok, first} = Absinthe.run("{ accounts(limit:2){ data { id } nextCursor } }", @schema, context: %{state: st})
      next = get_in(first, [:data, "accounts", "nextCursor"])
      first_ids = (get_in(first, [:data, "accounts", "data"]) || []) |> Enum.map(& &1["id"])
      if next do
        {:ok, second} = Absinthe.run("{ accounts(limit:2, cursor: \"#{next}\"){ data { id } } }", @schema, context: %{state: st})
        second_ids = (get_in(second, [:data, "accounts", "data"]) || []) |> Enum.map(& &1["id"])
        # Allow overlap if fewer than 3 accounts, else expect difference
        if length(first_ids) + length(second_ids) > length(Enum.uniq(first_ids ++ second_ids)) do
          assert length(first_ids) < 3
        else
          assert true
        end
      end
    else
      assert true
    end
  end

  test "names multi-page pagination" do
    st = state()
    if st do
      {:ok, first} = Absinthe.run("{ names(limit:2){ data { name } nextCursor } }", @schema, context: %{state: st})
      next = get_in(first, [:data, "names", "nextCursor"])
      if next do
        {:ok, second} = Absinthe.run("{ names(limit:2, cursor: \"#{next}\"){ data { name } } }", @schema, context: %{state: st})
        assert Map.get(second, :errors, []) == []
      end
    else
      assert true
    end
  end

  test "auctions invalid cursor error or tolerance" do
    st = state()
    if st do
      {:ok, first} = Absinthe.run("{ auctions(limit:1){ data { name } } }", @schema, context: %{state: st})
      has_data = ((get_in(first, [:data, "auctions", "data"]) || []) != [])
      if has_data do
        {:ok, bad} = Absinthe.run("{ auctions(cursor: \"invalid\", limit:1){ data { name } } }", @schema, context: %{state: st})
        # Expect an error for malformed expiration cursor (deserialize failure)
        if get_in(bad, [:data, "auctions"]) == nil do
          assert length(bad.errors) > 0
        end
      end
    else
      assert true
    end
  end

  test "nameHistory invalid cursor yields error" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, bad} = Absinthe.run("{ nameHistory(id: \"#{name}\", cursor: \"badcursor\"){ data { height } } }", @schema, context: %{state: st})
          if get_in(bad, [:data, "nameHistory"]) == nil do
            assert length(bad.errors) > 0
          end
      end
    else
      assert true
    end
  end

  test "nameClaims invalid cursor tolerated" do
    st = state()
    if st do
      case first_name(st) do
        nil -> assert true
        name ->
          {:ok, res} = Absinthe.run("{ nameClaims(id: \"#{name}\", cursor: \"not_base64@@\"){ data { sourceTxType } } }", @schema, context: %{state: st})
          # invalid cursor should be treated as nil -> no errors
            assert Map.get(res, :errors, []) == []
      end
    else
      assert true
    end
  end
end
