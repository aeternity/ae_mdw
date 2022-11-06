defmodule AeMdw.Db.OracleResponseMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.TestSamples, as: TS

  require Model

  describe "execute" do
    test "writes reward fee for an oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 1}
      txi = 1_000_000
      oracle_pk = TS.oracle_pk(0)
      query_id = TS.oracle_query_id(0)
      sender_pk = TS.address(0)
      fee = Enum.random(100..999)

      mutation =
        OracleResponseMutation.new(
          block_index,
          txi,
          oracle_pk,
          query_id
        )

      oracle_query =
        Model.oracle_query(
          index: {oracle_pk, query_id},
          txi: txi,
          sender_pk: sender_pk,
          fee: fee,
          expire: 15
        )

      store =
        store
        |> Store.put(Model.OracleQuery, oracle_query)
        |> change_store([mutation])

      int_key = {{height, txi}, "reward_oracle", oracle_pk, txi}
      kind_key = {"reward_oracle", {height, txi}, oracle_pk, txi}
      target_key = {oracle_pk, "reward_oracle", {height, txi}, txi}

      assert {:ok, Model.int_transfer_tx(index: ^int_key, amount: ^fee)} =
               Store.get(store, Model.IntTransferTx, int_key)

      assert {:ok, Model.kind_int_transfer_tx(index: ^kind_key)} =
               Store.get(store, Model.KindIntTransferTx, kind_key)

      assert {:ok, Model.target_kind_int_transfer_tx(index: ^target_key)} =
               Store.get(store, Model.TargetKindIntTransferTx, target_key)
    end
  end
end
