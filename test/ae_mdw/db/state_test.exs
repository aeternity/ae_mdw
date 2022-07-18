defmodule AeMdw.Db.StateTest do
  use ExUnit.Case

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import Mock

  require Model

  describe "commit_mem" do
    test "saves aex9 state into ets store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      {kbi, mbi} = block_index = {123_456, 2}
      next_kbi = kbi + 1
      call_txi = 12_345_678

      next_kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn
             ^next_kbi ->
               next_kb_hash
           end,
           get_next_hash: fn ^next_kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^ct_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => amount}

             {balances, nil}
           end
         ]}
      ] do
        state = State.enqueue(State.new(), :update_aex9_state, [ct_pk], [block_index, call_txi])
        assert %State{} = State.commit_mem(state, [])

        ets_state = State.new(AsyncStore.instance())
        presence_key = {account_pk, ct_pk}
        balance_key = {ct_pk, account_pk}

        assert {:ok, Model.aex9_account_presence(index: ^presence_key, txi: ^call_txi)} =
                 State.get(ets_state, Model.Aex9AccountPresence, presence_key)

        assert {:ok,
                Model.aex9_balance(
                  index: ^balance_key,
                  block_index: ^block_index,
                  txi: ^call_txi,
                  amount: ^amount
                )} = State.get(ets_state, Model.Aex9Balance, balance_key)
      end
    end
  end
end
