defmodule AeMdw.Migrations.AddContractCallInfoTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.DryRun.Contract, as: DryRunContract
  alias AeMdw.Migrations.AddContractCallInfo

  import Mock

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(AddContractCallInfo) do
    Code.require_file("priv/migrations/20261120120000_add_contract_call_info.ex")
  end

  # above the txis and heights of other tests
  @create_txi 3_000_000_000
  @call_txi 3_000_000_001
  @wrapped_call_txi 3_000_000_002
  @gc_call_txi 3_000_000_003
  @block_index {300_000_000, 0}

  test "writes the info of the calls the node still has, also when wrapped, and resumes" do
    [caller_pk, payer_pk, contract_pk] = for _i <- 1..3, do: :crypto.strong_rand_bytes(32)
    mb_hash = :crypto.strong_rand_bytes(32)

    call_aetx = DryRunContract.new_call_tx(caller_pk, contract_pk, "get", [])
    call_signed_tx = :aetx_sign.new(call_aetx, [])

    {:ok, paying_for_aetx} =
      :aec_paying_for_tx.new(%{
        payer_id: :aeser_id.create(:account, payer_pk),
        nonce: 1,
        fee: 100,
        tx: call_signed_tx
      })

    paying_for_signed_tx = :aetx_sign.new(paying_for_aetx, [])

    gc_signed_tx =
      :aetx_sign.new(DryRunContract.new_call_tx(payer_pk, contract_pk, "get", []), [])

    signed_txs = %{
      @call_txi => call_signed_tx,
      @wrapped_call_txi => paying_for_signed_tx,
      @gc_call_txi => gc_signed_tx
    }

    call_rec =
      :aect_call.new(
        :aeser_id.create(:account, caller_pk),
        1,
        :aeser_id.create(:contract, contract_pk),
        1,
        1_000_000_000
      )

    call_rec =
      :aect_call.set_log(
        [{contract_pk, [<<1::256>>], ""}],
        :aect_call.set_return_type(:revert, :aect_call.set_gas_used(77, call_rec))
      )

    gc_tx_hash = :aetx_sign.hash(gc_signed_tx)

    on_exit(fn ->
      Database.dirty_delete(Model.Block, @block_index)

      Enum.each(signed_txs, fn {txi, _signed_tx} ->
        Database.dirty_delete(Model.ContractCall, {@create_txi, txi})
        Database.dirty_delete(Model.Tx, txi)
        Database.dirty_delete(Model.ContractCallInfo, txi)
      end)
    end)

    Database.dirty_write(Model.Block, Model.block(index: @block_index, hash: mb_hash))

    Enum.each(signed_txs, fn {txi, signed_tx} ->
      Database.dirty_write(Model.ContractCall, Model.contract_call(index: {@create_txi, txi}))

      Database.dirty_write(
        Model.Tx,
        Model.tx(index: txi, id: :aetx_sign.hash(signed_tx), block_index: @block_index)
      )
    end)

    tx_hashes =
      Map.new(signed_txs, fn {_txi, signed_tx} -> {:aetx_sign.hash(signed_tx), signed_tx} end)

    with_mocks [
      {:aec_db, [:passthrough],
       [
         find_signed_tx: fn tx_hash ->
           case Map.fetch(tx_hashes, tx_hash) do
             {:ok, signed_tx} -> {:value, signed_tx}
             :error -> :none
           end
         end
       ]},
      {:aec_chain, [:passthrough],
       [
         get_contract_call: fn ^contract_pk, call_id, ^mb_hash ->
           if call_id == gc_call_id(gc_tx_hash, tx_hashes),
             do: {:error, :garbage_collected},
             else: {:ok, call_rec}
         end
       ]}
    ] do
      assert {:ok, 2} = AddContractCallInfo.run(State.new(), false)

      for txi <- [@call_txi, @wrapped_call_txi] do
        assert {:ok, Model.contract_call_info(gas_used: 77, return_type: :revert, logs_count: 1)} =
                 Database.fetch(Model.ContractCallInfo, txi)
      end

      assert :not_found = Database.fetch(Model.ContractCallInfo, @gc_call_txi)

      # the written calls are skipped, not written again
      assert {:ok, 0} = AddContractCallInfo.run(State.new(), false)
    end
  end

  defp gc_call_id(gc_tx_hash, tx_hashes) do
    {:contract_call_tx, call_tx} =
      tx_hashes |> Map.fetch!(gc_tx_hash) |> :aetx_sign.tx() |> :aetx.specialize_type()

    :aect_call_tx.call_id(call_tx)
  end
end
