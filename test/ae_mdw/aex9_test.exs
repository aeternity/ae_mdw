defmodule AeMdw.Aex9Test do
  use ExUnit.Case, async: false

  alias AeMdw.Aex9
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.UpdateAex9StateMutation
  alias AeMdw.Node.Db

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1, encode: 2]

  import Mock

  require Model

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

  describe "fetch_account_balances" do
    test "gets latest account balance from the chain" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)
      top_height_hash = Db.top_height_hash(true)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk, ^top_height_hash ->
             {:ok, {amount, top_height_hash}}
           end
         ]}
      ] do
        state =
          State.new_mem_state()
          |> State.put(
            Model.AexnContract,
            Model.aexn_contract(
              index: {:aex9, contract_pk},
              txi: 100,
              meta_info: {"name", "symbol", 18}
            )
          )
          |> State.put(
            Model.Aex9AccountPresence,
            Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: 100)
          )
          |> State.put(
            Model.Tx,
            Model.tx(index: 100, id: <<101::256>>, block_index: {11, 0})
          )
          |> State.put(
            Model.Block,
            Model.block(index: {11, 0}, hash: <<111::256>>)
          )

        assert {:ok, nil,
                [
                  %{
                    contract_id: encode_contract(contract_pk),
                    amount: amount,
                    block_hash: encode(:micro_block_hash, <<111::256>>),
                    decimals: 18,
                    height: 11,
                    token_name: "name",
                    token_symbol: "symbol",
                    tx_hash: encode(:tx_hash, <<101::256>>),
                    tx_index: 100,
                    tx_type: :contract_create_tx
                  }
                ],
                nil} ==
                 Aex9.fetch_account_balances(
                   state,
                   account_pk,
                   nil,
                   {:forward, false, 10, false}
                 )
      end
    end
  end
end
