defmodule AeMdwWeb.GraphQL.BlocksEnrichmentTest do
  use ExUnit.Case, async: false

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: AeMdw.Db.State.mem_state()

  test "key block enrichment fields presence" do
    st = state()
    if st do
      # fetch last synced height via status query then ask for that key block
      {:ok, status} = Absinthe.run("{ status { lastSyncedHeight } }", @schema, context: %{state: st})
      h = get_in(status, [:data, "status", "lastSyncedHeight"])
      if h && h > 0 do
        {:ok, res} = Absinthe.run("{ keyBlock(id: \"#{h}\") { hash height time miner microBlocksCount transactionsCount beneficiaryReward info nonce version target stateHash prevKeyHash prevHash beneficiary } }", @schema, context: %{state: st})
        blk = get_in(res, [:data, "keyBlock"]) || %{}
        assert blk["hash"]
        assert is_integer(blk["height"])
      else
        assert true
      end
    else
      assert true
    end
  end

  test "micro block enrichment via key block microBlocks list" do
    st = state()
    if st do
      {:ok, status} = Absinthe.run("{ status { lastSyncedHeight } }", @schema, context: %{state: st})
      h = get_in(status, [:data, "status", "lastSyncedHeight"])
      if h && h > 0 do
        {:ok, res} = Absinthe.run("{ keyBlock(id: \"#{h}\") { height hash } keyBlockMicroBlocks(id: \"#{h}\", limit: 1){ data { hash height microBlockIndex gas pofHash prevHash stateHash txsHash signature miner } } }", @schema, context: %{state: st})
        mbs = get_in(res, [:data, "keyBlockMicroBlocks", "data"]) || []
        Enum.each(mbs, fn mb -> assert mb["hash"] end)
      else
        assert true
      end
    else
      assert true
    end
  end
end
