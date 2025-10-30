defmodule AeMdwWeb.GraphQL.StatusQueryTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.State

  @moduletag :graphql

  defp run(q), do: Absinthe.run(q, AeMdwWeb.GraphQL.Schema, context: %{state: State.mem_state()})

  test "status returns richer fields" do
    {:ok, res} = run("{ status { last_synced_height partial last_key_block_hash last_key_block_time total_transactions pending_transactions } }")
    stat = get_in(res, [:data, "status"]) || %{}
    assert is_integer(stat["last_synced_height"]) or is_nil(stat["last_synced_height"])
    assert is_boolean(stat["partial"]) or is_nil(stat["partial"]) == false
    if stat["last_key_block_hash"], do: assert is_binary(stat["last_key_block_hash"])
    if stat["last_key_block_time"], do: assert is_integer(stat["last_key_block_time"])
    if stat["total_transactions"], do: assert is_integer(stat["total_transactions"]) and stat["total_transactions"] >= 0
    if stat["pending_transactions"], do: assert is_integer(stat["pending_transactions"]) and stat["pending_transactions"] >= 0
  end
end
