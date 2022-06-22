defmodule AeMdw.Db.ContractTest do
  use ExUnit.Case, async: false

  alias AeMdw.AexnContracts
  alias AeMdw.Db.Contract
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Validate

  alias Support.AeMdw.Db.ContractTestUtil

  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 1]
  import Mock

  @existing_cpk Validate.id!("ct_2uQYkMmupmAvBtSGtVLyua4EmcPAY62gKo4bSFEmfCNeNK9THX")
  @existing_apk Validate.id!("ak_eYHyfKSZiU3nzDTJBkrXAzVszoxDU4DHDw5xz6f2i5YVME234")
  @new_cpk Validate.id!("ct_2QKWLinRRozwA6wPAnW269hCHpkL1vcb2YCTrna94nP7rAPVU9")

  test "new aex9 presence not created when already exists" do
    fake_txi = 1_000_123
    {:ok, txn} = RocksDb.transaction_new()
    state = State.new() |> Map.put(:txn, txn)

    Contract.aex9_write_presence(state, @existing_cpk, fake_txi, @existing_apk)
    RocksDb.transaction_commit(txn)

    assert @existing_cpk
           |> ContractTestUtil.aex9_presence_txi_list(@existing_apk)
           |> Enum.find(&(&1 == fake_txi))

    {:ok, txn} = RocksDb.transaction_new()
    state = State.new() |> Map.put(:txn, txn)
    Contract.aex9_write_new_presence(state, @existing_cpk, fake_txi + 1, @existing_apk)
    RocksDb.transaction_commit(txn)

    refute @existing_cpk
           |> ContractTestUtil.aex9_presence_txi_list(@existing_apk)
           |> Enum.find(&(&1 == fake_txi + 1))
  end

  test "create and delete new aex9 presence" do
    {:ok, txn} = RocksDb.transaction_new()
    state = State.new() |> Map.put(:txn, txn)

    assert [] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)

    Contract.aex9_write_new_presence(state, @new_cpk, -1, @existing_apk)
    RocksDb.transaction_commit(txn)
    assert [-1] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)

    ContractTestUtil.aex9_delete_presence(@new_cpk, @existing_apk)
    assert [] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)
  end

  test "update AEX9 state on non AEX9 contract call with logs having AEX9 contracts" do
    assert {:ok, _pid} = Producer.start_link([])

    not_aex9_contract_pk =
      <<46, 45, 66, 42, 171, 23, 186, 153, 167, 41, 204, 175, 3, 32, 136, 142, 172, 72, 29, 171,
        231, 25, 168, 179, 135, 26, 13, 47, 67, 25, 57, 155>>

    non_aex9_log_pk =
      <<49, 69, 201, 179, 64, 73, 251, 153, 205, 37, 147, 13, 132, 58, 150, 207, 81, 149, 186,
        147, 107, 208, 117, 185, 160, 135, 239, 247, 134, 40, 7, 80>>

    {kbi, mbi} = block_index = {584_146, 26}
    create_txi = 27_821_849
    txi = 28_040_406

    log_aex9_pk1 =
      <<65, 110, 123, 208, 148, 244, 99, 197, 242, 18, 123, 8, 185, 211, 87, 178, 24, 148, 241,
        255, 75, 209, 104, 190, 48, 36, 223, 251, 112, 185, 157, 10>>

    log_aex9_pk2 =
      <<39, 26, 34, 124, 164, 250, 243, 90, 198, 12, 74, 70, 137, 147, 70, 150, 174, 68, 138, 188,
        64, 12, 26, 227, 206, 15, 221, 211, 50, 4, 47, 82>>

    log_aex9_pk3 =
      <<159, 45, 233, 232, 139, 49, 143, 243, 162, 116, 97, 118, 79, 163, 196, 185, 3, 243, 121,
        66, 71, 181, 89, 59, 168, 183, 214, 117, 202, 173, 171, 171>>

    meta_info1 = {"some-AEX9-65,110,123", "AEX9-65,110,123", 18}
    meta_info2 = {"some-AEX9-39, 26, 34", "AEX9-39, 26, 34", 18}
    meta_info3 = {"some-AEX9-159, 45, 233", "AEX9-159, 45, 233", 18}

    with_mocks [
      {
        AexnContracts,
        [],
        [
          is_aex9?: fn ct_pk -> ct_pk not in [not_aex9_contract_pk, non_aex9_log_pk] end,
          call_meta_info: fn _type, ct_pk ->
            case ct_pk do
              ^log_aex9_pk1 -> {:ok, meta_info1}
              ^log_aex9_pk2 -> {:ok, meta_info2}
              ^log_aex9_pk3 -> {:ok, meta_info3}
            end
          end,
          call_extensions: fn _type, _pk -> {:ok, []} end
        ]
      }
    ] do
      log_contracts = [
        {28_040_406, log_aex9_pk1},
        {27_821_843, log_aex9_pk2},
        {27_954_917, log_aex9_pk3},
        {27_821_847, non_aex9_log_pk}
      ]

      log_contracts
      |> Enum.reduce(State.new(), fn {create_txi, ct_pk}, state ->
        State.cache_put(state, :ct_create_sync_cache, ct_pk, create_txi)
      end)
      |> State.cache_put(:ct_create_sync_cache, not_aex9_contract_pk, create_txi)
      |> Contract.logs_write(block_index, create_txi, txi, call_rec("add_liquidity_ae"))

      assert %{enqueue_buffer: enqueue_buffer} = :sys.get_state(Producer)

      aex9_logs_update_pubkeys =
        log_contracts
        |> Enum.reverse()
        |> Kernel.--([{28_040_406, log_aex9_pk1}, {27_821_847, non_aex9_log_pk}])
        |> Enum.map(fn {_create_txi, contract_pk} ->
          {:update_aex9_state, [contract_pk], [block_index, txi]}
        end)

      assert aex9_logs_update_pubkeys -- enqueue_buffer == []

      assert Enum.any?(enqueue_buffer, fn async_task ->
               async_task == {:derive_aex9_presence, [log_aex9_pk1, kbi, mbi, txi], []}
             end)
    end
  end
end
