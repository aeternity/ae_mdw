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

  defp block_store do
    Store.put(empty_store(), Model.Block, Model.block(index: {@height, 0}))
  end
end
