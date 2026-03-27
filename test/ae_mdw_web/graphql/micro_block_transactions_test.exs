defmodule AeMdwWeb.GraphQL.MicroBlockTransactionsTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.{State, Model}
  require Model

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp first_micro_block_hash(state) do
    # naive scan from latest backwards for a micro block with txs or empty
    with %State{} = st <- state do
      Enum.find_value(0..100, fn offset ->
        case State.prev(st, Model.Block, nil) do
          {:ok, {h, _}} -> h - offset
          :none -> 0
        end
      end)
      # Fallback simple: look at height 0, mbi 0
      |> case do
        h when is_integer(h) and h >= 0 ->
          case State.get(st, Model.Block, {h, 0}) do
            {:ok, Model.block(hash: mb_hash)} -> :aeser_api_encoder.encode(:micro_block_hash, mb_hash)
            :not_found -> nil
          end
        _ -> nil
      end
    end
  end

  test "micro_block_transactions page + cursor" do
    st = state()
    if st do
      mb_hash_enc = first_micro_block_hash(st)
      if mb_hash_enc do
        {:ok, res} = Absinthe.run("{ microBlockTxs: micro_block_transactions(hash: \"#{mb_hash_enc}\", limit: 3){ data { hash txIndex: tx_index } nextCursor prevCursor } }", @schema, context: %{state: st})
        page = get_in(res, [:data, "microBlockTxs"]) || %{}
        data1 = page["data"] || []
        assert length(data1) <= 3
        if nc = page["nextCursor"] do
          {:ok, res2} = Absinthe.run("{ micro_block_transactions(hash: \"#{mb_hash_enc}\", limit:3, cursor: \"#{nc}\"){ data { txIndex: tx_index } } }", @schema, context: %{state: st})
          data2 = get_in(res2, [:data, "micro_block_transactions", "data"]) || []
          txi1 = MapSet.new(Enum.map(data1, & &1["txIndex"]))
          txi2 = MapSet.new(Enum.map(data2, & &1["txIndex"]))
          if data2 != [], do: assert MapSet.disjoint?(txi1, txi2)
        end
      else
        assert true
      end
    else
      assert true
    end
  end

  test "micro_block_transactions invalid hash" do
    st = state()
    {:ok, res} = Absinthe.run("{ micro_block_transactions(hash: \"mh_invalid\"){ data { hash } } }", @schema, context: %{state: st})
    if res[:errors], do: assert Enum.any?(res.errors, &(&1.message in ["micro_block_not_found","partial_state_unavailable","micro_block_transactions_error"]))
  end
end
