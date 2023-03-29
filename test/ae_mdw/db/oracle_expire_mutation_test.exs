defmodule AeMdw.Db.OraclesExpirationMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.TestSamples, as: TS

  require Model

  import Mock

  describe "execute" do
    test "inactivates an oracle that has just expired", %{store: store} do
      pubkey = <<123_451::256>>
      sync_height = 10_000

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: sync_height,
          register: {{sync_height - 5_000, 0}, {1_234, -1}},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, m_oracle)
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: {sync_height, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.ActiveOracleExpiration, {sync_height, pubkey})

      assert {:ok, ^m_oracle} = Store.get(store, Model.InactiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^sync_height, ^pubkey})} =
               Store.get(store, Model.InactiveOracleExpiration, {sync_height, pubkey})
    end

    test "does nothing when oracle has not expired yet",
         %{store: store} do
      pubkey = <<123_452::256>>
      sync_height = 10_000
      expire = sync_height + 1

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: expire,
          register: {{expire - 5_000, 0}, {1_234, -1}},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, m_oracle)
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: {expire, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.InactiveOracle, pubkey)
      assert :not_found = Store.get(store, Model.InactiveOracleExpiration, {sync_height, pubkey})

      assert {:ok, ^m_oracle} = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {expire, pubkey})
    end

    test "does nothing when oracle is already inactive", %{store: store} do
      pubkey = <<123_453::256>>
      sync_height = 10_000
      expire = sync_height - 1

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: expire,
          register: {{expire - 5_000, 0}, {1_234, -1}},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.InactiveOracle, m_oracle)
        |> Store.put(Model.InactiveOracleExpiration, Model.expiration(index: {expire, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, ^m_oracle} = Store.get(store, Model.InactiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^expire, ^pubkey})} =
               Store.get(store, Model.InactiveOracleExpiration, {expire, pubkey})
    end

    test "it expires oracle queries by creating internal transfers", %{store: store} do
      height = 234
      txi = 456
      oracle_pk = TS.oracle_pk(0)
      query_id = TS.oracle_query_id(0)
      sender_pk = TS.address(0)
      tx_hash = <<1::256>>

      oracle_query = Model.oracle_query(index: {oracle_pk, query_id}, txi_idx: {txi, -1})
      query_expiration = Model.oracle_query_expiration(index: {height, oracle_pk, query_id})

      {:ok, oracle_query_aetx} =
        :aeo_query_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          nonce: 1,
          oracle_id: :aeser_id.create(:oracle, oracle_pk),
          query: <<>>,
          query_fee: 2,
          query_ttl: {:delta, 3},
          response_ttl: {:delta, 4},
          fee: 5
        })

      {:oracle_query_tx, oracle_query_tx} = :aetx.specialize_type(oracle_query_aetx)

      store =
        store
        |> Store.put(Model.OracleQuery, oracle_query)
        |> Store.put(Model.OracleQueryExpiration, query_expiration)
        |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash))

      mutation = OraclesExpirationMutation.new(height)

      with_mocks [{DbUtil, [], [read_node_tx: fn _state, {^txi, -1} -> oracle_query_tx end]}] do
        store = change_store(store, [mutation])

        assert {:ok, _query_expiration} =
                 Store.get(store, Model.OracleQueryExpiration, {height, oracle_pk, query_id})

        assert {:ok, _query} = Store.get(store, Model.OracleQuery, {oracle_pk, query_id})

        assert {:ok, Model.int_transfer_tx(amount: 2)} =
                 Store.get(
                   store,
                   Model.IntTransferTx,
                   {{height, -1}, "fee_refund_oracle", sender_pk, {txi, -1}}
                 )
      end
    end
  end
end
