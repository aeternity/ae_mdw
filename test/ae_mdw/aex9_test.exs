defmodule AeMdw.Aex9Test do
  use ExUnit.Case

  alias AeMdw.Aex9
  alias AeMdw.Db.State

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]
  import Mock

  describe "fetch_balances" do
    test "gets contract balances from async store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      {kbi, mbi} = block_index = {123_456, 3}
      next_kbi = kbi + 1
      call_txi = 12_345_678

      next_kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)

      balances =
        for _i <- 1..10, into: %{} do
          account_pk = :crypto.strong_rand_bytes(32)
          amount = Enum.random(1_000_000_000..9_999_999_999)
          {{:address, account_pk}, amount}
        end

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn
             ^next_kbi ->
               next_kb_hash
           end,
           get_next_hash: fn ^next_kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^ct_pk, {:micro, ^kbi, ^next_mb_hash} ->
             {balances, nil}
           end
         ]}
      ] do
        state = State.enqueue(State.new(), :update_aex9_state, [ct_pk], [block_index, call_txi])
        assert %State{} = State.commit_mem(state, [])

        assert balances == Aex9.fetch_balances(nil, ct_pk, false)
      end
    end
  end

  describe "fetch_balance" do
    test "gets account balance from async store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      {kbi, mbi} = block_index = {123_456, 3}
      next_kbi = kbi + 1
      call_txi = 12_345_678

      next_kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)

      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      balances =
        for _i <- 1..10, into: %{} do
          account_pk = :crypto.strong_rand_bytes(32)
          amount = Enum.random(1_000_000_000..9_999_999_999)
          {{:address, account_pk}, amount}
        end
        |> Map.put({:address, account_pk}, amount)

      with_mocks [
        {
          AeMdw.AexnContracts,
          [],
          [
            is_aex9?: fn pk -> pk == ct_pk end
          ]
        },
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn
             ^next_kbi ->
               next_kb_hash
           end,
           get_next_hash: fn ^next_kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^ct_pk, {:micro, ^kbi, ^next_mb_hash} ->
             {balances, nil}
           end
         ]}
      ] do
        state = State.enqueue(State.new(), :update_aex9_state, [ct_pk], [block_index, call_txi])
        assert %State{} = State.commit_mem(state, [])

        assert {:ok,
                %{
                  contract: enc_ct(ct_pk),
                  account: enc_id(account_pk),
                  amount: amount
                }} == Aex9.fetch_balance(nil, ct_pk, account_pk)
      end
    end
  end
end
