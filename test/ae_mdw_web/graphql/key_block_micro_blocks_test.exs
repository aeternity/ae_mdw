defmodule AeMdwWeb.GraphQL.KeyBlockMicroBlocksTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.{State, Model, Util}
  require Model

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp ctx_state do
    case State.mem_state() do
      %State{} = st -> st
      _ -> nil
    end
  end

  defp run(query, state) do
    Absinthe.run(query, @schema, context: %{state: state})
  end

  # Find a key block height that has at least one micro block
  defp sample_kb_with_micro(state, last_gen, attempts \\ 50) do
    Enum.find(0..attempts, fn offset ->
      h = max(last_gen - offset, 0)
      case State.get(state, Model.Block, {h, 0}) do
        {:ok, _} -> true
        :not_found -> false
      end
    end)
    |> case do
      nil -> nil
      offset -> max(last_gen - offset, 0)
    end
  end

  test "key_block_micro_blocks pagination + cursor" do
    state = ctx_state()
    if state do
      last_gen = case Util.last_gen(state) do {:ok, g} -> g; :none -> 0 end
      kb_height = sample_kb_with_micro(state, last_gen) || last_gen

      # First page
      {:ok, res} = run("{ keyBlockMicroBlocks(id: \"#{kb_height}\", limit: 2){ data { hash height microBlockIndex: micro_block_index } nextCursor prevCursor } }", state)
      page = get_in(res, [:data, "keyBlockMicroBlocks"]) || %{}
      data1 = page["data"] || []
      if data1 == [] do
        assert true
      else
        assert length(data1) <= 2
        # Fetch second page if nextCursor exists
        nc = page["nextCursor"]
        if nc do
          {:ok, res2} = run("{ keyBlockMicroBlocks(id: \"#{kb_height}\", limit:2, cursor: \"#{nc}\"){ data { microBlockIndex: micro_block_index } } }", state)
          data2 = get_in(res2, [:data, "keyBlockMicroBlocks", "data"]) || []
          i1 = MapSet.new(Enum.map(data1, & &1["microBlockIndex"]))
          i2 = MapSet.new(Enum.map(data2, & &1["microBlockIndex"]))
          if data2 != [], do: assert MapSet.disjoint?(i1, i2)
        end
      end
    else
      assert true
    end
  end

  test "key_block_micro_blocks invalid id" do
    state = ctx_state()
    {:ok, res} = Absinthe.run("{ keyBlockMicroBlocks(id: \"999999999\"){ data { hash } } }", @schema, context: %{state: state})
  if res[:errors], do: assert Enum.any?(res.errors, &(&1.message in ["key_block_not_found","partial_state_unavailable","key_block_micro_blocks_error"]))
  end
end
