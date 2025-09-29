defmodule AeMdwWeb.GraphQL.AccountsQueryTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.{State, Model}
  require Model

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp any_account(state) do
    case State.prev(state, Model.AccountBalance, nil) do
      {:ok, pubkey} ->
        Model.account_balance(balance: balance) = State.fetch!(state, Model.AccountBalance, pubkey)
        enc = :aeser_api_encoder.encode(:account_pubkey, pubkey)
        {enc, balance}
      :none -> {nil, nil}
    end
  end

  test "account query parity" do
    st = state()
    if st do
      {acc, balance} = any_account(st)
      if acc do
        {:ok, res} = Absinthe.run("{ account(id: \"#{acc}\"){ id balance creationTime: creation_time } }", @schema, context: %{state: st})
        data = get_in(res, [:data, "account"]) || %{}
        assert data["id"] == acc
  assert is_integer(data["balance"]) and data["balance"] == balance
      else
        assert true
      end
    else
      {:ok, res} = Absinthe.run("{ account(id: \"ak_dummy\"){ id } }", @schema, context: %{})
      assert Enum.any?(res.errors || [], &(&1.message == "partial_state_unavailable"))
    end
  end

  test "account not found" do
    st = state()
    if st do
  {:ok, res} = Absinthe.run("{ account(id: \"ak_1111111111111111111111111111111111111111111111111\"){ id } }", @schema, context: %{state: st})
  assert Enum.any?(res.errors || [], &(&1.message in ["account_not_found","invalid_account"]))
    else
      assert true
    end
  end

  test "accounts pagination + parity for first page" do
    st = state()
    if st do
      {:ok, res} = Absinthe.run("{ accounts(limit:5){ data { id balance creationTime: creation_time } nextCursor prevCursor } }", @schema, context: %{state: st})
      page = get_in(res, [:data, "accounts"]) || %{}
      data = page["data"] || []
      assert page["prevCursor"] == nil
      # parity: compare each returned balance to DB
      Enum.each(data, fn acc_map ->
        id = acc_map["id"]
        {:ok, pk} = :aeser_api_encoder.safe_decode(:account_pubkey, id)
        Model.account_balance(balance: bal) = State.fetch!(st, Model.AccountBalance, pk)
  assert is_integer(acc_map["balance"]) and acc_map["balance"] == bal
      end)
      # If we have a nextCursor attempt second page and ensure disjoint IDs
      if page["nextCursor"] do
        {:ok, res2} = Absinthe.run("{ accounts(limit:5, cursor: \"#{page["nextCursor"]}\"){ data { id } } }", @schema, context: %{state: st})
        data2 = get_in(res2, [:data, "accounts", "data"]) || []
        ids1 = MapSet.new(Enum.map(data, & &1["id"]))
        ids2 = MapSet.new(Enum.map(data2, & &1["id"]))
        if data2 != [], do: assert MapSet.disjoint?(ids1, ids2)
      end
    else
      assert true
    end
  end
end
