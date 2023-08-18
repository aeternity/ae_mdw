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

  require Model

  describe "fetch_logs/5" do
    test "lists logs sorted by call txi and log index" do
      {height, _mbi} = block_index = {100_000, 11}
      contract_pk = :crypto.strong_rand_bytes(32)
      <<evt_hash_bigger_int::256>> = aexn_event_hash(:transfer)
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
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      assert {_prev, [log1, log2], _next} =
               Contracts.fetch_logs(state, {:forward, false, 100, false}, nil, %{}, nil)

      assert {create_txi, call_txi, 0} == log1
      assert {create_txi, call_txi, 1} == log2
    end
  end
end
