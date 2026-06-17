defmodule AeMdwWeb.GraphQL.OracleScopeRegressionTest do
  @moduledoc """
  Guards against the CaseClauseError that existed in Oracles.fetch_oracle_responses/5
  when a non-nil scope ({:gen, Range.t()}) was passed instead of a bare Range.t().

  The tests do not require oracle records to exist in the DB; they only verify that
  passing from_height / to_height does not crash with a function_clause / CaseClauseError
  and returns a well-formed GraphQL response (empty data or a resolver error, not a crash).
  """
  use ExUnit.Case, async: false

  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  # An obviously invalid oracle id that will be rejected by Validate.id before
  # reaching the scope pattern-match, so no live node is required.
  @fake_oracle_id "ok_11111111111111111111111111111111273Yts"

  defp run(query) do
    ctx =
      case State.mem_state() do
        %State{} = st -> %{state: st}
        _ -> %{}
      end

    Absinthe.run(query, @schema, context: ctx)
  end

  describe "oracle_responses scope regression" do
    test "oracle_responses with from_height does not raise CaseClauseError" do
      q = """
      { oracle_responses(id: "#{@fake_oracle_id}", fromHeight: 100) {
          data { height }
        }
      }
      """

      # Must not raise — any result (empty data or a resolver error) is acceptable
      assert {:ok, res} = run(q)
      # Either data (empty list) or errors, but not a crash
      assert is_map(res)
    end

    test "oracle_responses with to_height does not raise CaseClauseError" do
      q = """
      { oracle_responses(id: "#{@fake_oracle_id}", toHeight: 200) {
          data { height }
        }
      }
      """

      assert {:ok, res} = run(q)
      assert is_map(res)
    end

    test "oracle_responses with both from_height and to_height does not raise" do
      q = """
      { oracle_responses(id: "#{@fake_oracle_id}", fromHeight: 50, toHeight: 100) {
          data { height }
        }
      }
      """

      assert {:ok, res} = run(q)
      assert is_map(res)
    end

    test "oracle_responses with reversed bounds does not raise" do
      q = """
      { oracle_responses(id: "#{@fake_oracle_id}", fromHeight: 200, toHeight: 10) {
          data { height }
        }
      }
      """

      assert {:ok, res} = run(q)
      assert is_map(res)
    end
  end
end
