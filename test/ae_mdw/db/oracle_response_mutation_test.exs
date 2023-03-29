defmodule AeMdw.Db.OracleResponseMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.TestSamples, as: TS

  require Model

  import Mock

  describe "execute" do
    test "writes reward fee for an oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 1}
      txi = 1_000_000
      txi2 = 2_000_000
      oracle_pk = TS.oracle_pk(0)
      query_id = TS.oracle_query_id(0)
      sender_pk = TS.address(0)
      query_fee = 2
      tx_hash = <<1::256>>

      mutation =
        OracleResponseMutation.new(
          block_index,
          {txi2, -1},
          oracle_pk,
          query_id
        )

      oracle_query = Model.oracle_query(index: {oracle_pk, query_id}, txi_idx: {txi, -1})

      {:ok, oracle_query_aetx} =
        :aeo_query_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          nonce: 1,
          oracle_id: :aeser_id.create(:oracle, oracle_pk),
          query: <<>>,
          query_fee: query_fee,
          query_ttl: {:delta, 3},
          response_ttl: {:delta, 4},
          fee: 5
        })

      {:oracle_query_tx, oracle_query_tx} = :aetx.specialize_type(oracle_query_aetx)

      int_key = {{height, {txi2, -1}}, "reward_oracle", oracle_pk, {txi, -1}}
      kind_key = {"reward_oracle", {height, {txi2, -1}}, oracle_pk, {txi, -1}}
      target_key = {oracle_pk, "reward_oracle", {height, {txi2, -1}}, {txi, -1}}

      with_mocks [{DbUtil, [], [read_node_tx: fn _state, {^txi, -1} -> oracle_query_tx end]}] do
        store =
          store
          |> Store.put(Model.OracleQuery, oracle_query)
          |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash))
          |> change_store([mutation])

        assert {:ok, Model.int_transfer_tx(index: ^int_key, amount: ^query_fee)} =
                 Store.get(store, Model.IntTransferTx, int_key)

        assert {:ok, Model.kind_int_transfer_tx(index: ^kind_key)} =
                 Store.get(store, Model.KindIntTransferTx, kind_key)

        assert {:ok, Model.target_kind_int_transfer_tx(index: ^target_key)} =
                 Store.get(store, Model.TargetKindIntTransferTx, target_key)
      end
    end
  end
end
