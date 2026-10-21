defmodule AeMdw.Db.UtilTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil

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

  defp block_store do
    Store.put(empty_store(), Model.Block, Model.block(index: {@height, 0}))
  end
end
