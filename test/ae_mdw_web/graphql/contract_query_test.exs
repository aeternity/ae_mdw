defmodule AeMdwWeb.GraphQL.ContractQueryTest do
  use ExUnit.Case, async: true
  test "contract query with invalid id returns error" do
    query = "{ contract(id: \"bad\") { id } }"
    {:ok, _result} = ensure_minimal_state()
    {:ok, %{errors: errs}} = Absinthe.run(query, AeMdwWeb.GraphQL.Schema, context: %{})
    assert Enum.any?(errs, fn %{message: msg} -> String.contains?(msg, "invalid_contract_id") end)
  end

  defp ensure_minimal_state do
    # Placeholder: if resolvers require state later, inject mock or lightweight state here.
    {:ok, :noop}
  end
end
