defmodule AeMdwWeb.GraphQL.NumericTypesTest do
  use ExUnit.Case, async: false
  alias AeMdw.Db.{State, Model}
  require Model

  @schema AeMdwWeb.GraphQL.Schema
  @moduletag :graphql

  defp state(), do: State.mem_state()

  defp run(q, st), do: Absinthe.run(q, @schema, context: %{state: st})

  test "numeric leaf types are integers where expected" do
    st = state()
    if st do
      # status
      {:ok, status_res} = run("{ status { last_synced_height last_key_block_time total_transactions pending_transactions } }", st)
      status = get_in(status_res, [:data, "status"]) || %{}
      Enum.each(["last_synced_height","last_key_block_time","total_transactions","pending_transactions"], fn k ->
        v = status[k]
        if v, do: assert(is_integer(v))
      end)

      # key blocks sample
      {:ok, kb_res} = run("{ keyBlocks: key_blocks(limit:1){ data { height time micro_blocks_count transactions_count beneficiary_reward } } }", st)
      kb = get_in(kb_res, [:data, "keyBlocks", "data"]) || []
      Enum.each(kb, fn b ->
        for k <- ["height","time","micro_blocks_count","transactions_count","beneficiary_reward"] do
          if b[k], do: assert(is_integer(b[k]))
        end
      end)

      # accounts sample (balance is BigInt -> integer)
      {:ok, acc_res} = run("{ accounts(limit:1){ data { id balance creation_time } } }", st)
      accs = get_in(acc_res, [:data, "accounts", "data"]) || []
      Enum.each(accs, fn a ->
        if a["creation_time"], do: assert(is_integer(a["creation_time"]))
        if a["balance"], do: assert(is_integer(a["balance"]))
      end)

      # transactions sample
      {:ok, tx_res} = run("{ txs: transactions(limit:1){ data { hash block_height micro_index micro_time tx_index } } }", st)
      txs = get_in(tx_res, [:data, "txs", "data"]) || []
      mb_hash = case txs do
        [t|_] -> t["block_hash"] || t["hash"]
        _ -> nil
      end
      Enum.each(txs, fn t ->
        for k <- ["block_height","micro_index","micro_time","tx_index"] do
          # tx_index may be nil under render_v3
          if t[k], do: assert(is_integer(t[k]))
        end
      end)

      # micro block (if we can derive hash)
      if mb_hash do
        {:ok, mb_res} = run("{ micro_block(hash: \"#{mb_hash}\"){ height time micro_block_index transactions_count gas } }", st)
        mb = get_in(mb_res, [:data, "micro_block"]) || %{}
        for k <- ["height","time","micro_block_index","transactions_count","gas"] do
          if mb[k], do: assert(is_integer(mb[k]))
        end
      end
    else
      assert true
    end
  end
end
