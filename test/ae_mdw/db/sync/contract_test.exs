defmodule AeMdw.Db.Sync.ContractTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Model.Field
  alias AeMdw.Db.Sync.Contract

  import Mock

  require Model

  describe "events/3" do
    test "it creates an internal call for each event that's not Chain.create/clone" do
      create_txi = 1
      call_txi = 3
      tx_1 = :tx1
      tx_2 = :tx2

      events = [
        {{:internal_call_tx, "some_funname_1"}, %{info: tx_1}},
        {{:internal_call_tx, "some_funname_2"}, %{info: tx_2}}
      ]

      with_mocks [
        {DbContract, [],
         [
           int_call_write: fn _create_txi, _call_txi, _index, _fname, _tx -> :ok end
         ]}
      ] do
        Contract.events(events, call_txi, create_txi)

        assert_called(DbContract.int_call_write(create_txi, call_txi, 0, "some_funname_1", tx_1))
        assert_called(DbContract.int_call_write(create_txi, call_txi, 1, "some_funname_2", tx_2))
      end
    end

    test "it creates an Field record for each Chain.create/clone event, using the next Call.amount event" do
      create_txi = 1
      call_txi = 3
      tx_1 = :tx1
      tx_2 = :tx2

      events = [
        {{:internal_call_tx, "Chain.create"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_1}},
        {{:internal_call_tx, "Chain.clone"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_2}}
      ]

      contract_id =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      with_mocks [
        {DbContract, [],
         [
           int_call_write: fn _create_txi, _call_txi, _index, _fname, _tx -> :ok end
         ]},
        {:aetx, [], [specialize_type: fn _tx -> {:spend_tx, %{}} end]},
        {:aec_spend_tx, [], [recipient_id: fn _tx -> {:id, :account, contract_id} end]},
        {:mnesia, [], [write: fn _tab, _record, _lock -> :ok end]}
      ] do
        Contract.events(events, call_txi, create_txi)

        assert_called(DbContract.int_call_write(create_txi, call_txi, 0, "Call.amount", tx_1))
        assert_called(DbContract.int_call_write(create_txi, call_txi, 1, "Call.amount", tx_2))

        assert_called(
          :mnesia.write(
            Field,
            Model.field(index: {:contract_call_tx, nil, contract_id, call_txi}),
            :write
          )
        )

        assert_called(
          :mnesia.write(
            Field,
            Model.field(index: {:contract_call_tx, nil, contract_id, call_txi}),
            :write
          )
        )
      end
    end
  end
end
