defmodule AeMdw.Sync.AsyncTasks.WealthRankAccountsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Contract
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts
  alias AeMdw.Validate

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, tx: 3]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 1, fun_args_res: 1]
  import Mock

  describe "micro_block_accounts/2" do
    test "finds the Chain.spend recipients in the mutations sync builds" do
      contract_pk = <<7::256>>
      recipient_pk = :crypto.strong_rand_bytes(32)

      spend_event =
        {{:internal_call_tx, "Chain.spend"}, %{info: spend_aetx(contract_pk, recipient_pk, 0)}}

      call_tx =
        tx(:contract_call_tx, :alice, %{contract_id: :aeser_id.create(:contract, contract_pk)})

      with_blockchain %{alice: 10_000}, mb: [tx1: call_tx] do
        %{hash: mb_hash} = blocks[:mb]
        {:id, :account, alice_pk} = accounts[:alice]

        with_mocks [
          {Contract, [:passthrough],
           get_grouped_events: fn micro_block ->
             Map.new(:aec_blocks.txs(micro_block), &{:aetx_sign.hash(&1), [spend_event]})
           end,
           call_tx_info: fn _tx, ^contract_pk, ^contract_pk, _block_hash ->
             {fun_args_res("transfer"), call_rec("transfer")}
           end,
           exists?: fn pubkey -> pubkey == contract_pk end}
        ] do
          found_accounts =
            0
            |> Block.blocks_mutations(0, 0, Validate.id!(mb_hash))
            |> Enum.flat_map(fn {_height, blocks_mutations} -> blocks_mutations end)
            |> Enum.reject(fn {{_height, mbi}, _block, _mutations} -> mbi == -1 end)
            |> Enum.map(fn {_block_index, micro_block, mutations} ->
              WealthRankAccounts.micro_block_accounts(micro_block, mutations)
            end)
            |> Enum.reduce(MapSet.new(), &MapSet.union/2)

          assert MapSet.equal?(MapSet.new([alice_pk, recipient_pk]), found_accounts)
        end
      end
    end

    test "returns a set of transaction and Chain.spend accounts, without contracts" do
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      account_pk3 = :crypto.strong_rand_bytes(32)
      account_pk4 = :crypto.strong_rand_bytes(32)
      account_pk5 = :crypto.strong_rand_bytes(32)
      contract_pk = :crypto.strong_rand_bytes(32)
      # a contract whose protected clone failed is gone from the chain
      removed_contract_pk = :crypto.strong_rand_bytes(32)

      aetx1 = spend_aetx(account_pk1, account_pk2, 1)

      txs = [
        :aetx_sign.new(aetx1, [])
      ]

      micro_block =
        :aec_blocks.new_micro(
          1,
          <<0::256>>,
          <<1::256>>,
          <<>>,
          <<>>,
          txs,
          System.system_time(),
          :no_fraud,
          0
        )

      int_calls =
        [
          {"Chain.spend", spend_aetx(account_pk3, account_pk4, 2)},
          {"Call.amount", spend_aetx(removed_contract_pk, contract_pk, 2)},
          {"Chain.spend", spend_aetx(contract_pk, account_pk5, 0)}
        ]
        |> Enum.with_index(fn {fname, aetx}, idx ->
          {tx_type, tx_rec} = :aetx.specialize_type(aetx)
          {idx, fname, tx_type, aetx, tx_rec}
        end)

      # each transaction's mutations are in a list of their own
      mutations = [nil, [nil, IntCallsMutation.new(:crypto.strong_rand_bytes(32), 1, int_calls)]]

      with_mock Contract, exists?: fn pubkey -> pubkey == contract_pk end do
        assert MapSet.equal?(
                 MapSet.new([account_pk1, account_pk2, account_pk3, account_pk4, account_pk5]),
                 WealthRankAccounts.micro_block_accounts(micro_block, mutations)
               )
      end
    end
  end

  defp spend_aetx(sender_pk, recipient_pk, nonce) do
    {:ok, aetx} =
      :aec_spend_tx.new(%{
        sender_id: :aeser_id.create(:account, sender_pk),
        recipient_id: :aeser_id.create(:account, recipient_pk),
        amount: 123,
        fee: 0,
        nonce: nonce,
        payload: <<>>
      })

    aetx
  end
end
