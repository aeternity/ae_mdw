defmodule AeMdw.Db.Sync.BlockTest do
  use ExUnit.Case

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Block

  import AeMdwWeb.BlockchainSim,
    only: [with_blockchain: 3, tx: 3, spend_tx: 3, name_tx: 3, name_tx: 4]

  import Mock

  require Model

  describe "blocks_mutations/4" do
    test "returns the mutations for a generation with many transactions" do
      # credo:disable-for-next-line
      accounts = Map.new(0..100, fn i -> {String.to_atom("user#{i}"), 100_000_000} end)

      first_microblock = {
        :mb0,
        List.flatten(
          Enum.map(1..30, fn i ->
            # credo:disable-for-next-line
            tx_tag = String.to_atom("tx#{i}")
            user = String.to_existing_atom("user#{i}")
            name = "name#{i}.chain"
            {tx_tag, name_tx(:name_claim_tx, user, name)}
          end) ++
            Enum.map(31..40, fn i ->
              # credo:disable-for-next-line
              tx_tag = String.to_atom("tx#{i}")
              user = String.to_existing_atom("user#{i}")
              {tx_tag, tx(:oracle_register_tx, user, %{})}
            end) ++
            Enum.map(41..100, fn i ->
              # credo:disable-for-next-line
              tx_tag = String.to_atom("tx#{i}")
              user = String.to_existing_atom("user#{i}")
              {tx_tag, spend_tx(user, user, 1_000)}
            end)
        )
      }

      microblocks =
        Enum.map(1..10, fn i ->
          # credo:disable-for-next-line
          mb_tag = String.to_atom("mb#{i}")
          user = String.to_existing_atom("user#{i}")
          oracle_id = :aeser_id.create(:oracle, <<i::256>>)

          {
            mb_tag,
            [
              tx1:
                name_tx(:name_update_tx, user, "name#{i}.chain", %{
                  pointers: [{:pointer, "account_pubkey", user}]
                }),
              tx2: {:oracle_query_tx, user, oracle_id, %{}}
            ] ++
              Enum.map(3..50, fn i ->
                tx_tag = String.to_existing_atom("tx#{i}")
                user = String.to_existing_atom("user#{i}")
                {tx_tag, spend_tx(user, user, 1_000)}
              end)
          }
        end)

      with_blockchain accounts, [first_microblock | microblocks] do
        %{hash: last_mb_hash, height: 10} = blocks[:mb10]
        last_mb_hash = AeMdw.Validate.id!(last_mb_hash)

        assert mem1 = :ets.info(:sync_hashes, :memory)
        assert height_blocks = 0 |> Block.blocks_mutations(0, 0, last_mb_hash) |> Enum.to_list()
        assert ^height_blocks = 0 |> Block.blocks_mutations(0, 0, last_mb_hash) |> Enum.to_list()
        assert length(height_blocks) == 11
        assert mem2 = :ets.info(:sync_hashes, :memory)
        assert mem2 > mem1
      end
    end
  end
end
