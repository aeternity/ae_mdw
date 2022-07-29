defmodule AeMdw.Aex9Test do
  use ExUnit.Case

  alias AeMdw.Aex9
  alias AeMdw.Db.State
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.UpdateAex9StateMutation

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]
  import Mock

  describe "fetch_balances" do
    test "gets contract balances from async store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      block_index = {123_456, 3}
      call_txi = 12_345_678

      balances =
        for _i <- 1..10, into: %{} do
          account_pk = :crypto.strong_rand_bytes(32)
          amount = Enum.random(1_000_000_000..9_999_999_999)
          {{:address, account_pk}, amount}
        end

      balances_list =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      async_state = State.new(AsyncStore.instance())

      Mutation.execute(
        UpdateAex9StateMutation.new(ct_pk, block_index, call_txi, balances_list),
        async_state
      )

      assert balances == Aex9.fetch_balances(nil, ct_pk, false)
    end
  end

  describe "fetch_balance" do
    test "gets account balance from async store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      block_index = {123_456, 3}
      call_txi = 12_345_678

      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      balances =
        for _i <- 1..10, into: %{} do
          account_pk = :crypto.strong_rand_bytes(32)
          amount = Enum.random(1_000_000_000..9_999_999_999)
          {{:address, account_pk}, amount}
        end
        |> Map.put({:address, account_pk}, amount)

      balances_list =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      async_state = State.new(AsyncStore.instance())

      Mutation.execute(
        UpdateAex9StateMutation.new(ct_pk, block_index, call_txi, balances_list),
        async_state
      )

      with_mocks [
        {
          AeMdw.AexnContracts,
          [],
          [
            is_aex9?: fn pk -> pk == ct_pk end
          ]
        }
      ] do
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
