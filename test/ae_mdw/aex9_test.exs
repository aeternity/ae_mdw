defmodule AeMdw.Aex9Test do
  use ExUnit.Case

  alias AeMdw.Aex9
  alias AeMdw.Db.State
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.UpdateAex9StateMutation

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1]

  import Mock

  describe "fetch_balances" do
    test "gets contract balances from async store" do
      contract_pk = :crypto.strong_rand_bytes(32)
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
        UpdateAex9StateMutation.new(contract_pk, call_txi, balances_list),
        async_state
      )

      assert balances == Aex9.fetch_balances(State.new(), contract_pk, false)
    end
  end

  describe "fetch_balance" do
    test "gets latest account balance from the chain" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk, nil -> {:ok, {amount, <<1::256>>}} end
         ]}
      ] do
        assert {:ok,
                %{
                  contract: encode_contract(contract_pk),
                  account: encode_account(account_pk),
                  amount: amount
                }} == Aex9.fetch_balance(contract_pk, account_pk, nil)
      end
    end
  end
end
