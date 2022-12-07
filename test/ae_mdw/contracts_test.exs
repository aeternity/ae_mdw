defmodule AeMdw.ContractsTest do
  use ExUnit.Case

  alias AeMdw.Contracts
  alias AeMdw.Db.Contract
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 5]
  import AeMdw.Util.Encoding

  require Model

  describe "fetch_logs/5" do
    test "lists logs sorted by call txi and log index" do
      {height, mbi} = block_index = {100_000, 11}
      contract_pk = :crypto.strong_rand_bytes(32)
      <<evt_hash_bigger_int::256>> = evt_hash0 = aexn_event_hash(:transfer)
      evt_hash1 = <<evt_hash_bigger_int - 1::256>>
      extra_logs = [{contract_pk, [evt_hash1, <<3::256>>, <<4::256>>, <<1::256>>], <<>>}]
      call_rec = call_rec("transfer", contract_pk, height, contract_pk, extra_logs)

      call_txi = height * 1_000
      create_txi = call_txi - 2
      block_hash = <<100_011::256>>

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index)
        )
        |> State.put(Model.Block, Model.block(index: block_index, hash: block_hash))
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, create_txi)
        |> Contract.logs_write(block_index, create_txi, call_txi, call_rec)

      assert {:ok, _prev, [log1, log2], _next} =
               Contracts.fetch_logs(state, {:forward, false, 100, false}, nil, %{}, nil)

      contract_id = encode_contract(contract_pk)
      contract_tx_hash = encode_to_hash(state, create_txi)
      call_tx_hash = encode_to_hash(state, call_txi)
      mb_hash = encode(:micro_block_hash, block_hash)

      event_hash0 = Base.hex_encode32(evt_hash0)
      event_hash1 = Base.hex_encode32(evt_hash1)

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash0,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 0,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: nil
             } = log1

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash1,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 1,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: nil
             } = log2
    end

    test "lists logs with remote calls" do
      {height, mbi} = block_index = {100_000, 12}
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk = :crypto.strong_rand_bytes(32)
      evt_hash0 = aexn_event_hash(:transfer)
      evt_hash1 = <<123::256>>
      extra_logs = [{remote_pk, [evt_hash1, <<3::256>>, <<4::256>>, <<1234::256>>], <<>>}]
      call_rec = call_rec("transfer", contract_pk, height, contract_pk, extra_logs)

      call_txi = height * 1_000
      remote_txi = call_txi - 2
      create_txi = call_txi - 1
      block_hash = <<100_012::256>>

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: remote_txi, id: <<remote_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index)
        )
        |> State.put(Model.Block, Model.block(index: block_index, hash: block_hash))
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
        )
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {remote_txi, :contract_create_tx, remote_pk})
        )
        |> State.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> State.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, remote_pk, remote_txi})
        )
        |> Contract.logs_write(block_index, create_txi, call_txi, call_rec)

      assert {:ok, _prev, [log1, log2], _next} =
               Contracts.fetch_logs(state, {:forward, false, 100, false}, nil, %{}, nil)

      contract_id = encode_contract(contract_pk)
      contract_tx_hash = encode_to_hash(state, create_txi)
      remote_id = encode_contract(remote_pk)
      remote_tx_hash = encode_to_hash(state, remote_txi)

      call_tx_hash = encode_to_hash(state, call_txi)
      mb_hash = encode(:micro_block_hash, block_hash)

      event_hash0 = Base.hex_encode32(evt_hash0)
      event_hash1 = Base.hex_encode32(evt_hash1)

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash0,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 0,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: nil
             } = log1

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash1,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 1,
               ext_caller_contract_txi: ^remote_txi,
               ext_caller_contract_tx_hash: ^remote_tx_hash,
               ext_caller_contract_id: ^remote_id,
               parent_contract_id: nil
             } = log2

      assert {:ok, _prev, [log3], _next} =
               Contracts.fetch_logs(
                 state,
                 {:forward, false, 100, false},
                 nil,
                 %{"contract" => remote_id},
                 nil
               )

      assert %{
               contract_id: ^remote_id,
               contract_tx_hash: ^remote_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash1,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 1,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: ^contract_id
             } = log3
    end
  end
end
