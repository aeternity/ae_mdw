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

  describe "get_blocks_per_height/2 on a hyperchain" do
    # Like on a hyperchain, a micro block takes the height of the key block that
    # closes its generation: kb0 <- mb1 <- kb1 <- mb2a <- mb2b <- kb2 <- mb3 (top).
    setup do
      kb0 = {:key, 0, <<100::256>>, nil}
      mb1 = {:micro, 1, <<1::256>>, <<100::256>>}
      kb1 = {:key, 1, <<101::256>>, <<100::256>>}
      mb2a = {:micro, 2, <<2::256>>, <<101::256>>}
      mb2b = {:micro, 2, <<3::256>>, <<101::256>>}
      kb2 = {:key, 2, <<102::256>>, <<101::256>>}
      mb3 = {:micro, 3, <<4::256>>, <<102::256>>}

      headers = Map.new([kb0, mb1, kb1, mb2a, mb2b, kb2, mb3], &{elem(&1, 2), &1})
      generations = %{kb0 => [], kb1 => [mb1], kb2 => [mb2a, mb2b]}

      mocks = [
        {AeMdw.Sync.Hyperchain, [:passthrough], hyperchain?: fn -> true end},
        {:aec_db, [:passthrough],
         get_header: &Map.fetch!(headers, &1), get_block: &Map.fetch!(headers, &1)},
        {:aec_headers, [:passthrough],
         type: &elem(&1, 0), hash_header: &{:ok, elem(&1, 2)}, prev_key_hash: &elem(&1, 3)},
        {:aec_blocks, [:passthrough],
         to_header: & &1, height: &elem(&1, 1), prev_key_hash: &elem(&1, 3)},
        {:aec_chain, [:passthrough],
         genesis_block: fn -> kb0 end,
         get_key_header_by_height: fn height ->
           {:ok, Enum.find([kb0, kb1, kb2], &(elem(&1, 1) == height))}
         end,
         get_generation_by_hash: fn hash, :backward ->
           key_block = Map.fetch!(headers, hash)
           {:ok, %{key_block: key_block, micro_blocks: Map.fetch!(generations, key_block)}}
         end}
      ]

      %{mocks: mocks, kb0: kb0, mb1: mb1, kb1: kb1, mb2a: mb2a, mb2b: mb2b, kb2: kb2, mb3: mb3}
    end

    test "with a micro block on top, ends at the key block before it", ctx do
      %{mb1: mb1, kb1: kb1, mb2a: mb2a, mb2b: mb2b, kb2: kb2, mb3: mb3} = ctx

      with_mocks ctx.mocks do
        assert [{^kb1, [^mb1], kb2_hash}, {^kb2, [^mb2a, ^mb2b], nil}] =
                 Db.get_blocks_per_height(1, elem(mb3, 2))

        assert kb2_hash == elem(kb2, 2)
      end
    end

    test "with a key block on top, ends at its generation", ctx do
      %{mb1: mb1, kb1: kb1, mb2a: mb2a, mb2b: mb2b, kb2: kb2} = ctx

      with_mocks ctx.mocks do
        assert [{^kb1, [^mb1], kb2_hash}, {^kb2, [^mb2a, ^mb2b], nil}] =
                 Db.get_blocks_per_height(1, elem(kb2, 2))

        assert kb2_hash == elem(kb2, 2)
      end
    end

    test "up to a height, ends with the key block after it", ctx do
      %{mb1: mb1, kb1: kb1, kb2: kb2} = ctx

      with_mocks ctx.mocks do
        assert [{^kb1, [^mb1], kb2_hash}] = Db.get_blocks_per_height(1, 1)
        assert kb2_hash == elem(kb2, 2)
      end
    end

    test "from below the genesis height, stops at the genesis block", ctx do
      %{kb0: kb0, kb1: kb1, kb2: kb2, mb3: mb3} = ctx

      with_mocks ctx.mocks do
        assert [{^kb0, [], kb1_hash}, {^kb1, _mbs1, _kb2_hash}, {^kb2, _mbs2, nil}] =
                 Db.get_blocks_per_height(-1, elem(mb3, 2))

        assert kb1_hash == elem(kb1, 2)
        assert_not_called(:aec_chain.get_generation_by_hash(nil, :_))
      end
    end

    test "doesn't read the generation below from_height", ctx do
      %{kb1: kb1, kb2: kb2, mb3: mb3} = ctx

      with_mocks ctx.mocks do
        assert [{^kb2, [_mb2a, _mb2b], nil}] = Db.get_blocks_per_height(2, elem(mb3, 2))
        assert_not_called(:aec_chain.get_generation_by_hash(elem(kb1, 2), :_))
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

  describe "find_block_height_time/1" do
    test "returns the height and time from the block header" do
      mb_hash = :crypto.strong_rand_bytes(32)
      unknown_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aec_db, [],
         [
           find_header: fn
             ^mb_hash -> {:value, :header}
             ^unknown_hash -> :none
           end
         ]},
        {:aec_headers, [], [height: fn :header -> 7 end, time_in_msecs: fn :header -> 123 end]}
      ] do
        assert {:ok, 7, 123} = Db.find_block_height_time(mb_hash)
        assert :none = Db.find_block_height_time(unknown_hash)
      end
    end
  end

  describe "find_block_tx_hashes/1" do
    test "returns the node's tx hashes of the block, or :error when the node db fails" do
      [mb_hash, unknown_hash, failing_hash, tx_hash1, tx_hash2] =
        for _i <- 1..5, do: :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aec_db, [],
         [
           find_block_tx_hashes: fn
             ^mb_hash -> {:value, [tx_hash1, tx_hash2]}
             ^unknown_hash -> :none
             ^failing_hash -> exit(:no_transaction)
           end
         ]}
      ] do
        assert {:ok, [^tx_hash1, ^tx_hash2]} = Db.find_block_tx_hashes(mb_hash)
        assert :none = Db.find_block_tx_hashes(unknown_hash)
        assert :error = Db.find_block_tx_hashes(failing_hash)
      end
    end
  end
end
