defmodule AeMdw.Db.OracleResponseMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.OracleResponseMutation

  require Model

  describe "execute" do
    test "writes reward fee for an oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 1}
      txi = 1_000_000
      pubkey = <<1::256>>
      fee = Enum.random(100..999)

      mutation =
        OracleResponseMutation.new(
          block_index,
          txi,
          pubkey,
          fee
        )

      store = change_store(store, [mutation])

      int_key = {{height, txi}, "reward_oracle", pubkey, txi}
      kind_key = {"reward_oracle", {height, txi}, pubkey, txi}
      target_key = {pubkey, "reward_oracle", {height, txi}, txi}

      assert {:ok, Model.int_transfer_tx(index: ^int_key, amount: ^fee)} =
               Store.get(store, Model.IntTransferTx, int_key)

      assert {:ok, Model.kind_int_transfer_tx(index: ^kind_key)} =
               Store.get(store, Model.KindIntTransferTx, kind_key)

      assert {:ok, Model.target_kind_int_transfer_tx(index: ^target_key)} =
               Store.get(store, Model.TargetKindIntTransferTx, target_key)
    end
  end
end
