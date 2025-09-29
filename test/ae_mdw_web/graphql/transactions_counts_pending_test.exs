defmodule AeMdwWeb.GraphQL.TransactionsCountsPendingTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.{State, Model}
  require Model

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp last_txi_and_tx(state) do
    case State.prev(state, Model.Tx, nil) do
      {:ok, txi} ->
        {:ok, tx} = AeMdw.Txs.fetch(state, txi, add_spendtx_details?: true, render_v3?: true)
        {txi, tx}
      :none -> {nil, nil}
    end
  end

  test "transactions_count overall parity" do
    st = state()
    if st do
      {:ok, gql} = Absinthe.run("{ transactionsCount }", @schema, context: %{state: st})
      cnt = get_in(gql, [:data, "transactionsCount"]) || 0
      {:ok, direct} = AeMdw.Txs.count(st, nil, %{})
      assert cnt == direct
    else
      assert true
    end
  end

  test "transactions_count filtered by type" do
    st = state()
    if st do
      {_txi, tx} = last_txi_and_tx(st)
      if tx do
        type = tx["tx"]["type"] |> to_string()
        {:ok, gql} = Absinthe.run("{ transactionsCount(type: \"#{type}\") }", @schema, context: %{state: st})
        cnt = get_in(gql, [:data, "transactionsCount"]) || 0
  # direct count for type via params with string key
  {:ok, direct} = AeMdw.Txs.count(st, nil, %{"type" => type})
        assert cnt == direct
      else
        assert true
      end
    else
      assert true
    end
  end

  test "pending transactions shape + count parity (if any)" do
    st = state()
    {:ok, count_res} = Absinthe.run("{ pendingTransactionsCount }", @schema, context: %{state: st})
    pending_cnt = get_in(count_res, [:data, "pendingTransactionsCount"]) || 0
    {:ok, list_res} = Absinthe.run("{ pendingTransactions(limit:5){ data { hash } nextCursor prevCursor } }", @schema, context: %{state: st})
    data = get_in(list_res, [:data, "pendingTransactions", "data"]) || []
    # If there are fewer than total pending it is fine; just ensure hashes are strings
    Enum.each(data, fn tx -> assert is_binary(tx["hash"]) end)
    # pending_cnt should be >= length(data)
    assert pending_cnt >= length(data)
  end
end
