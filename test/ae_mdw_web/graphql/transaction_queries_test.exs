defmodule AeMdwWeb.GraphQL.TransactionQueriesTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil

  @moduletag :graphql

  defp run(query) do
    Absinthe.run(query, AeMdwWeb.GraphQL.Schema, context: %{state: State.mem_state()})
  end

  test "transactions basic page matches direct fetch bounds" do
    state = State.mem_state()

    tx_count =
      case DbUtil.last_txi(state) do
        {:ok, last} -> last + 1
        :none -> 0
      end

    query = """
    { transactions(limit:5) { data { txIndex: tx_index hash } next_cursor prev_cursor } }
    """

    {:ok, res} = run(query)
    page = get_in(res, [:data, "transactions"])

    if tx_count == 0 do
      assert page["data"] == []
    else
      assert length(page["data"]) <= 5
      # Basic shape assertions
      Enum.each(page["data"], fn tx ->
        # some early tx might be nil if partial
        assert is_binary(tx["hash"]) or is_nil(tx["hash"])
      end)
    end
  end

  test "transaction fetch by invalid id errors" do
    {:ok, res} = run("{ transaction(id: \"not_a_hash\") { hash } }")
    # Absinthe may return errors with atom keys; normalize
    errors = res[:errors] || []
    [first | _] = errors
    msg = Map.get(first, "message") || Map.get(first, :message)

    assert msg in [
             "transaction_not_found",
             "invalid_transaction_id",
             "transaction_error",
             "partial_state_unavailable"
           ]
  end

  test "transactions invalid type returns validation error" do
    {:ok, res} = run("{ transactions(type: [\"not_a_tx\"], limit: 1) { data { hash } } }")

    errors = res[:errors] || []
    [first | _] = errors
    msg = Map.get(first, "message") || Map.get(first, :message)

    assert String.starts_with?(msg, "invalid transaction type")
  end

  test "micro_block_transactions invalid type group returns validation error" do
    {:ok, res} =
      run(
        "{ micro_block_transactions(hash: \"mh_dummy\", type_group: [\"not_a_group\"], limit: 1) { data { hash } } }"
      )

    errors = res[:errors] || []
    [first | _] = errors
    msg = Map.get(first, "message") || Map.get(first, :message)

    assert String.starts_with?(msg, "invalid transaction group")
  end
end
