defmodule AeMdw.ContractsTest do
  use ExUnit.Case

  alias AeMdw.Contracts
  alias AeMdw.Db.Contract
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 5]
  import AeMdw.TestUtil, only: [empty_state: 0]
  import AeMdw.Util.Encoding

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
        empty_state()
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

      assert {:ok, {_prev, [log1, log2], _next}} =
               Contracts.fetch_logs(state, {:forward, false, 100, false}, nil, %{}, nil)

      assert {create_txi, call_txi, 0} == log1
      assert {create_txi, call_txi, 1} == log2
    end
  end

  describe "fetch_calls/5" do
    test "lists calls sorted by call txi and log index" do
      nonce = Enum.random(100..999)
      owner_pk = <<nonce::256>>

      {:ok, aetx} =
        :aect_create_tx.new(%{
          owner_id: :aeser_id.create(:account, owner_pk),
          nonce: nonce,
          code: "code",
          vm_version: 7,
          abi_version: 3,
          deposit: 100,
          amount: 200,
          gas: 0,
          gas_price: 300,
          call_data: <<43, 17, 68, 214, 68, 31, 59, 36, 2, 0>>,
          fee: 0
        })

      {tx_type, tx_rec} = :aetx.specialize_type(aetx)

      int_calls = [
        {0, "Call.amount", tx_type, aetx, tx_rec},
        {1, "Chain.create", tx_type, aetx, tx_rec}
      ]

      contract_pk = :aect_create_tx.contract_pubkey(tx_rec)

      {height, _mbi} = block_index = {100_000, 11}
      call_txi = height * 1_000
      create_txi = call_txi - 2
      block_hash = <<100_011::256>>

      state =
        empty_state()
        |> State.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
        )
        |> State.put(Model.Block, Model.block(index: block_index, hash: block_hash))
        |> State.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index)
        )

      state =
        IntCallsMutation.execute(
          IntCallsMutation.new(contract_pk, call_txi, int_calls),
          state
        )

      assert {:ok, {_prev, [call1, call2], _next}} =
               Contracts.fetch_calls(state, {:forward, false, 100, false}, nil, %{}, nil)

      contract_id = encode_contract(contract_pk)

      assert %{
               local_idx: 0,
               call_txi: ^call_txi,
               contract_txi: ^create_txi,
               internal_tx: %{"contract_id" => ^contract_id}
             } = call1

      assert %{
               local_idx: 1,
               call_txi: ^call_txi,
               contract_txi: ^create_txi,
               internal_tx: %{"contract_id" => ^contract_id}
             } = call2
    end
  end
end
