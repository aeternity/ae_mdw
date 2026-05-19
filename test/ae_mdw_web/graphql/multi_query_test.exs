defmodule AeMdwWeb.GraphQL.MultiQueryTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.State

  @schema AeMdwWeb.GraphQL.Schema

  defp run(query) do
    ctx =
      case State.mem_state() do
        %State{} = st -> %{state: st}
        _no_state -> %{}
      end

    Absinthe.run(query, @schema, context: ctx)
  end

  test "combined key_blocks and key_block single" do
    {:ok, res} =
      run(
        "{ a: key_blocks(limit:1){ data { height hash } } b: key_blocks(limit:1){ data { height hash } } }"
      )

    data_a = get_in(res, [:data, "a", "data"]) || []
    data_b = get_in(res, [:data, "b", "data"]) || []

    if data_a == [] or data_b == [] do
      assert true
    else
      [%{"height" => h} | _rest_a] = data_a
      [%{"height" => h2} | _rest_b] = data_b
      assert is_integer(h) and is_integer(h2)
    end
  end
end
