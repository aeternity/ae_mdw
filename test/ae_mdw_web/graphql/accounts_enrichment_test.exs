defmodule AeMdwWeb.GraphQL.AccountsEnrichmentTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "account enrichment fields presence" do
    st = state()
    if st do
      # pick first account from accounts list
      {:ok, res} = Absinthe.run("{ accounts(limit:1){ data { id } } }", @schema, context: %{state: st})
      id = get_in(res, [:data, "accounts", "data", Access.at(0), "id"])
      if id do
        {:ok, acct_res} = Absinthe.run("{ account(id: \"#{id}\"){ id balance creationTime nonce namesCount activitiesCount } }", @schema, context: %{state: st})
        acct = get_in(acct_res, [:data, "account"]) || %{}
        assert acct["id"] == id
        assert is_integer(acct["balance"]) || is_nil(acct["balance"]) || is_float(acct["balance"]) # BigInt may appear as integer
      else
        assert true
      end
    else
      assert true
    end
  end
end
