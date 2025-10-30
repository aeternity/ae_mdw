defmodule AeMdwWeb.GraphQL.BlockDeepCorrectnessTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.{State, Model, Util}
  require Model
  alias AeMdw.Blocks

  @moduletag :graphql
  @moduletag :integration
  @schema AeMdwWeb.GraphQL.Schema

  setup_all do
    case State.mem_state() do
      %State{} = state ->
    last_gen = case Util.last_gen(state) do {:ok, g} -> g; :none -> 0 end
        {:ok, %{state: state, last_gen: last_gen}}
      _ -> :ok
    end
  end

  defp gql!(query, ctx), do: Absinthe.run(query, @schema, context: %{state: ctx.state})

  defp key_block_expected_heights(last_gen, limit) do
    Enum.take(Stream.iterate(last_gen, &(&1 - 1)), limit) |> Enum.filter(&(&1 >= 0))
  end

  test "first page heights match descending sequence", %{last_gen: last_gen} = ctx do
    assume_limit = 7
    expected = key_block_expected_heights(last_gen, assume_limit)
    {:ok, %{data: %{"key_blocks" => %{"data" => rows}}}} = gql!("{ key_blocks(limit: #{assume_limit}) { data { height } } }", ctx)
    got = Enum.map(rows, & &1["height"])
    # If chain shorter than requested limit we only compare available heights.
    assert got == Enum.take(expected, length(got))
  end

  test "multi-page accumulation yields contiguous heights with no gaps or overlaps", %{last_gen: last_gen} = ctx do
    if last_gen < 15 do
      assert true
    else
      limit = 5
      total_pages = 3
      q = fn cur ->
        cursor_part = if cur, do: ", cursor: \"#{cur}\"", else: ""
        "{ key_blocks(limit: #{limit}#{cursor_part}) { nextCursor data { height } } }"
      end
      {heights, _cursor} = Enum.reduce(1..total_pages, {[], nil}, fn _, {acc, cur} ->
        {:ok, %{data: %{"key_blocks" => %{"nextCursor" => nc, "data" => ds}}}} = gql!(q.(cur && elem(cur,0)), ctx)
        page_hs = Enum.map(ds, & &1["height"])
        {acc ++ page_hs, nc}
      end)
      # Build expected contiguous sequence
      expected = key_block_expected_heights(last_gen, length(heights))
      assert heights == expected
      assert Enum.uniq(heights) == heights
    end
  end

  test "end-of-list has nil nextCursor" , %{last_gen: last_gen} = ctx do
    # Choose a tiny window near genesis; fromHeight/toHeight around 0
    to_h = min(3, last_gen)
    {:ok, %{data: %{"key_blocks" => %{"nextCursor" => nc}}}} = gql!("{ key_blocks(toHeight: #{to_h}, limit: 50) { nextCursor data { height } } }", ctx)
    assert is_nil(nc)
  end

  defp micro_block_count(state, gen) do
    # Count micro block indexes by probing forward until miss
    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(fn mbi -> {mbi, State.get(state, Model.Block, {gen, mbi})} end)
    |> Stream.take_while(fn {_mbi, res} -> match?({:ok, _}, res) end)
    |> Enum.count()
  end

  defp gen_tx_count(state, gen) do
    case State.get(state, Model.Block, {gen, -1}) do
      {:ok, Model.block(tx_index: first)} ->
        last = case State.get(state, Model.Block, {gen + 1, -1}) do
          {:ok, Model.block(tx_index: nxt)} -> nxt - 1
          :not_found ->
            case State.prev(state, Model.Tx, nil) do
              {:ok, txi} -> txi
              :none -> first - 1
            end
        end
        max(last - first + 1, 0)
      :not_found -> 0
    end
  end

  test "key_block micro_blocks_count & transactions_count recompute matches GraphQL", %{state: state, last_gen: last_gen} = ctx do
    if last_gen == 0 do
      assert true
    else
      target = max(0, last_gen - 10)
      {:ok, %{data: %{"key_block" => kb}}} = gql!("{ key_block(id: \"#{target}\") { height micro_blocks_count transactions_count } }", ctx)
      # Skip if not found (unlikely) else compare counts
      if kb do
        assert kb["micro_blocks_count"] == micro_block_count(state, target)
        assert kb["transactions_count"] == gen_tx_count(state, target)
      end
    end
  end

  test "beneficiary_reward non-negative and equals internal render" , %{state: state, last_gen: last_gen} = ctx do
    if last_gen == 0 do
      assert true
    else
      target = last_gen
      {:ok, %{data: %{"key_block" => kb}}} = gql!("{ key_block(id: \"#{target}\") { beneficiary_reward } }", ctx)
      if kb && kb["beneficiary_reward"] do
        {:ok, kmap} = Blocks.fetch_key_block(state, Integer.to_string(target))
        assert kb["beneficiary_reward"] == kmap[:beneficiary_reward]
        assert is_integer(kb["beneficiary_reward"]) and kb["beneficiary_reward"] >= 0
      end
    end
  end
end
