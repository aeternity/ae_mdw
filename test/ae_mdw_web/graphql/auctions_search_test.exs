defmodule AeMdwWeb.GraphQL.AuctionsSearchTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  test "auctions list basic" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ auctions(limit:1){ data { name auctionEnd } } }", @schema, context: %{state: st})
      _ = get_in(res, [:data, "auctions", "data"]) || []
      assert Map.get(res, :errors, []) == []
    else
      assert true
    end
  end

  test "search names basic" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ searchNames(prefix:\"a\", limit:2){ data { type name } } }", @schema, context: %{state: st})
      assert Map.get(res, :errors, []) == []
    else
      assert true
    end
  end
end
