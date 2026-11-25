defmodule AeMdw.Db.UtilTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db

  require Model

  import AeMdw.TestUtil, only: [empty_store: 0]
  import Mock

  @height 100
  @time 1_700_000_000_000
  @key_block_time 1_600_000_000_000
  @tx_time 1_500_000_000_000

  describe "last_gen_and_time/1" do
    test "returns :no_blocks when there are no blocks" do
      assert :no_blocks = DbUtil.last_gen_and_time(State.new(empty_store()))
    end

    test "prefers the last Model.Time key" do
      state =
        block_store()
        |> Store.put(Model.Time, Model.time(index: {@time, 10}))
        |> Store.put(Model.KeyBlockTime, Model.key_block_time(index: @key_block_time))
        |> Store.put(Model.Tx, Model.tx(index: 10, time: @tx_time))
        |> State.new()

      with_mock State, [:passthrough], [] do
        assert {:ok, {@height, @time}} = DbUtil.last_gen_and_time(state)

        assert_not_called(State.prev(:_, Model.KeyBlockTime, :_))
        assert_not_called(State.prev(:_, Model.Tx, :_))
      end
    end

    test "falls back to the last Model.KeyBlockTime key" do
      state =
        block_store()
        |> Store.put(Model.KeyBlockTime, Model.key_block_time(index: @key_block_time))
        |> Store.put(Model.Tx, Model.tx(index: 10, time: @tx_time))
        |> State.new()

      assert {:ok, {@height, @key_block_time}} = DbUtil.last_gen_and_time(state)
    end

    test "falls back to the last tx time" do
      state =
        block_store()
        |> Store.put(Model.Tx, Model.tx(index: 10, time: @tx_time))
        |> State.new()

      assert {:ok, {@height, @tx_time}} = DbUtil.last_gen_and_time(state)
    end

    test "approximates the time when no table has it" do
      state =
        block_store()
        |> Store.put(Model.Tx, Model.tx(index: 10, time: nil))
        |> State.new()

      assert {:ok, {@height, time}} = DbUtil.last_gen_and_time(state)
      assert time == @height * 180_000
    end
  end

  describe "micro_blocks_count/2" do
    test "counts the micro blocks of a generation" do
      state =
        [{99, -1..0}, {100, -1..2}, {101, -1..-1}, {102, -1..0}]
        |> Enum.flat_map(fn {height, mbis} -> Enum.map(mbis, &{height, &1}) end)
        |> Enum.reduce(empty_store(), &Store.put(&2, Model.Block, Model.block(index: &1)))
        |> State.new()

      assert 3 = DbUtil.micro_blocks_count(state, 100)
      assert 0 = DbUtil.micro_blocks_count(state, 101)
      assert 1 = DbUtil.micro_blocks_count(state, 102)
      assert 0 = DbUtil.micro_blocks_count(state, 103)
      assert 0 = DbUtil.micro_blocks_count(State.new(empty_store()), 100)
    end
  end

  describe "time_to_txi/3" do
    test "finds the same txis with every tx, only the micro block boundaries, or a mix of both" do
      # {mb_time, first_txi, last_txi}, the last two micro blocks share a time
      micro_blocks = [{1_000, 0, 0}, {2_000, 1, 4}, {3_000, 5, 6}, {5_000, 7, 9}, {5_000, 10, 12}]

      rows = fn txis ->
        for {mb_time, first_txi, last_txi} <- micro_blocks,
            txi <- txis.(first_txi, last_txi),
            do: {mb_time, txi}
      end

      every_tx = rows.(&Enum.to_list(&1..&2))
      boundaries = rows.(&Enum.uniq([&1, &2]))
      mixed = Enum.uniq(boundaries ++ Enum.filter(every_tx, &(elem(&1, 0) <= 2_000)))

      [every_tx_state, boundaries_state, mixed_state] =
        Enum.map([every_tx, boundaries, mixed], &time_state/1)

      times = [0, 999, 1_000, 1_001, 2_000, 2_500, 3_000, 4_000, 5_000, 6_000]

      for first <- times, last <- times do
        expected = DbUtil.time_to_txi(every_tx_state, first, last)

        assert DbUtil.time_to_txi(boundaries_state, first, last) == expected
        assert DbUtil.time_to_txi(mixed_state, first, last) == expected
      end

      assert {1, 6} = DbUtil.time_to_txi(boundaries_state, 1_500, 3_000)
      assert {7, 12} = DbUtil.time_to_txi(boundaries_state, 5_000, 5_000)
      assert {-1, -1} = DbUtil.time_to_txi(boundaries_state, 6_000, 7_000)
    end
  end

  defp time_state(keys) do
    keys
    |> Enum.reduce(empty_store(), &Store.put(&2, Model.Time, Model.time(index: &1)))
    |> State.new()
  end

  describe "read_node_tx/2" do
    test "reads an internal call tx without the outer tx" do
      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, <<1::256>>),
          recipient_id: :aeser_id.create(:account, <<2::256>>),
          amount: 123,
          fee: 0,
          nonce: 0,
          payload: <<>>
        })

      {:spend_tx, spend_tx} = :aetx.specialize_type(aetx)

      state =
        empty_store()
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {10, 0}, fname: "Chain.spend", tx: aetx)
        )
        |> State.new()

      with_mock Db, [:passthrough], [] do
        assert ^spend_tx = DbUtil.read_node_tx(state, {10, 0})

        assert_not_called(Db.get_tx_data(:_))
      end
    end
  end

  describe "micro_block_height_index/2" do
    test "reads the index from the first tx's rows without walking the node headers" do
      with_mocks [
        {Db, [],
         find_block_height_time: fn
           <<0::256>> -> {:ok, @height, 1_000}
           <<2::256>> -> {:ok, @height, 3_000}
         end,
         get_reverse_micro_hashes: fn _hash -> [] end}
      ] do
        state = micro_blocks_state()

        assert {:ok, @height, 0} = DbUtil.micro_block_height_index(state, encode_mb(0))
        assert {:ok, @height, 2} = DbUtil.micro_block_height_index(state, encode_mb(2))

        assert_not_called(Db.get_reverse_micro_hashes(:_))
      end
    end

    test "walks the node headers when the rows don't lead to the block" do
      with_mocks [
        {Db, [],
         find_block_height_time: fn
           # the empty micro block
           <<1::256>> -> {:ok, @height, 2_000}
           # a micro fork: mdw holds another block with this time
           <<9::256>> -> {:ok, @height, 3_000}
           # a block of the previous generation has the same time
           <<10::256>> -> {:ok, @height + 1, 1_000}
           # missing from the node, so the test-only Model.Block scan finds it without a time
           <<2::256>> -> :none
         end,
         get_reverse_micro_hashes: fn
           <<1::256>> -> [<<0::256>>]
           <<9::256>> -> [<<8::256>>, <<7::256>>, <<6::256>>]
           <<10::256>> -> []
           <<2::256>> -> [<<1::256>>, <<0::256>>]
         end}
      ] do
        state = micro_blocks_state()

        assert {:ok, @height, 1} = DbUtil.micro_block_height_index(state, encode_mb(1))
        assert {:ok, @height, 3} = DbUtil.micro_block_height_index(state, encode_mb(9))
        assert DbUtil.micro_block_height_index(state, encode_mb(10)) == {:ok, @height + 1, 0}
        assert {:ok, @height, 2} = DbUtil.micro_block_height_index(state, encode_mb(2))
      end
    end
  end

  # Generation @height: mbi 0 holds txs 0..1 at time 1_000, mbi 1 is empty at 2_000 and mbi 2
  # holds txs 2..4 at 3_000. Generation @height + 1: mbi 0 holds tx 5, also at 1_000.
  defp micro_blocks_state do
    blocks = [
      {{@height, -1}, nil, 0},
      {{@height, 0}, <<0::256>>, 0},
      {{@height, 1}, <<1::256>>, 2},
      {{@height, 2}, <<2::256>>, 2},
      {{@height + 1, -1}, nil, 5},
      {{@height + 1, 0}, <<10::256>>, 5}
    ]

    txs = [
      {0, {@height, 0}},
      {1, {@height, 0}},
      {2, {@height, 2}},
      {3, {@height, 2}},
      {4, {@height, 2}},
      {5, {@height + 1, 0}}
    ]

    times = [{1_000, 0}, {1_000, 1}, {3_000, 2}, {3_000, 4}, {1_000, 5}]

    store =
      Enum.reduce(blocks, empty_store(), fn {index, hash, txi}, store ->
        Store.put(store, Model.Block, Model.block(index: index, hash: hash, tx_index: txi))
      end)

    store =
      Enum.reduce(txs, store, fn {txi, block_index}, store ->
        Store.put(store, Model.Tx, Model.tx(index: txi, block_index: block_index))
      end)

    times
    |> Enum.reduce(store, &Store.put(&2, Model.Time, Model.time(index: &1)))
    |> State.new()
  end

  defp encode_mb(n), do: :aeser_api_encoder.encode(:micro_block_hash, <<n::256>>)

  defp block_store do
    Store.put(empty_store(), Model.Block, Model.block(index: {@height, 0}))
  end
end
