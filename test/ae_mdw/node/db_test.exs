defmodule AeMdw.Node.DbTest do
  use ExUnit.Case

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3]
  import Mock

  alias AeMdw.Node.Db
  alias AeMdw.Validate

  describe "get_blocks_per_height/2" do
    test "doesn't read the generation below from_height" do
      with_blockchain %{alice: 10_000},
        mb0: [t0: spend_tx(:alice, :alice, 1)],
        mb1: [t1: spend_tx(:alice, :alice, 1)],
        mb2: [t2: spend_tx(:alice, :alice, 1)] do
        mb2_hash = Validate.id!(blocks[:mb2].hash)

        assert [{kb2, [_mb2], nil}] = Db.get_blocks_per_height(2, mb2_hash)
        assert 2 == :aec_blocks.height(kb2)

        assert_not_called(:aec_db.get_block(Validate.id!(blocks[:mb1].hash)))
        assert_not_called(:aec_db.get_block(Validate.id!(blocks[1].hash)))
      end
    end
  end

  describe "get_next_hash/2" do
    test "returns the block after the micro block reading headers only" do
      [kb_hash, mb_hash0, mb_hash1, mb_hash2, next_kb_hash] =
        for _i <- 1..5, do: :crypto.strong_rand_bytes(32)

      headers = %{
        next_kb_hash => {:key, mb_hash2},
        mb_hash2 => {:micro, mb_hash1},
        mb_hash1 => {:micro, mb_hash0},
        mb_hash0 => {:micro, kb_hash},
        kb_hash => {:key, <<0::256>>}
      }

      with_mocks [
        {:aec_db, [], [get_header: &Map.fetch!(headers, &1)]},
        {:aec_headers, [], [type: &elem(&1, 0), prev_hash: &elem(&1, 1)]}
      ] do
        assert mb_hash1 == Db.get_next_hash(next_kb_hash, 0)
        assert mb_hash2 == Db.get_next_hash(next_kb_hash, 1)
        assert next_kb_hash == Db.get_next_hash(next_kb_hash, 2)
      end
    end
  end
end
