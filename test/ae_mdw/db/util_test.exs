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
