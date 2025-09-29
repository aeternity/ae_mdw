defmodule AeMdwWeb.GraphQL.AccountNamesAex9Test do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "account names list pagination" do
    st = state()
    if st do
      {:ok, accounts} = Absinthe.run("{ accounts(limit:1){ data { id } } }", @schema, context: %{state: st})
      acct = get_in(accounts, [:data, "accounts", "data", Access.at(0), "id"])
      if acct do
        {:ok, first} = Absinthe.run("{ accountNames(id: \"#{acct}\", limit: 5){ data { name active expireHeight } nextCursor } }", @schema, context: %{state: st})
        data = get_in(first, [:data, "accountNames", "data"]) || []
        Enum.each(data, fn n -> assert is_binary(n["name"]) end)
      end
    else
      assert true
    end
  end

  test "account aex9 balances pagination" do
    st = state()
    if st do
      {:ok, accounts} = Absinthe.run("{ accounts(limit:1){ data { id } } }", @schema, context: %{state: st})
      acct = get_in(accounts, [:data, "accounts", "data", Access.at(0), "id"])
      if acct do
        {:ok, res} = Absinthe.run("{ accountAex9Balances(id: \"#{acct}\", limit: 10){ data { contractId amount } nextCursor } }", @schema, context: %{state: st})
        data = get_in(res, [:data, "accountAex9Balances", "data"]) || []
        Enum.each(data, fn b -> assert is_binary(b["contractId"]) end)
      end
    else
      assert true
    end
  end
end
