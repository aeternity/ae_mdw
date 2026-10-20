defmodule AeMdw.MinerStats.FactsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Facts
  alias AeMdw.Node.Db

  import AeMdw.TestUtil, only: [empty_store: 0]
  import Mock

  require Model

  @miner <<1::256>>
  @beneficiary <<2::256>>

  describe "fetch/2" do
    test "it reads the generation from the header and the database" do
      height = 100

      store =
        empty_store()
        |> Store.put(Model.Block, Model.block(index: {height, -1}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {height, 0}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {height, 1}, tx_index: 12))
        |> Store.put(Model.Block, Model.block(index: {height + 1, -1}, tx_index: 13))
        |> Store.put(Model.Tx, Model.tx(index: 9, fee: 1_000))
        |> Store.put(Model.Tx, Model.tx(index: 10, fee: 1))
        |> Store.put(Model.Tx, Model.tx(index: 11, fee: 2))
        |> Store.put(Model.Tx, Model.tx(index: 12, fee: 3))
        |> Store.put(Model.Tx, Model.tx(index: 13, fee: 1_000))
        |> put_block_reward(height, @beneficiary, 7)
        |> put_block_reward(height, <<3::256>>, 5)
        |> put_block_reward(height + 1, @beneficiary, 1_000)

      with_mocks [
        {Db, [], [get_key_header: fn ^height -> {:ok, header(height)} end]},
        {:aec_headers, [:passthrough],
         [difficulty: fn _header -> 123 end, info: fn _header -> 42 end]}
      ] do
        assert {:ok,
                %{
                  height: ^height,
                  time: 5_000,
                  miner: @miner,
                  beneficiary: @beneficiary,
                  info: 42,
                  difficulty: 123,
                  micro_blocks: 2,
                  txs: 3,
                  fees: 6,
                  rewards: %{@beneficiary => 7, <<3::256>> => 5}
                }} = Facts.fetch(State.new(store), height)
      end
    end

    test "it has no info when the header has the default one" do
      with_mocks [
        {Db, [], [get_key_header: fn _height -> {:ok, header(100)} end]},
        {:aec_headers, [:passthrough], [difficulty: fn _header -> 123 end]}
      ] do
        assert {:ok, %{info: nil, micro_blocks: 0, txs: 0, fees: 0, rewards: rewards}} =
                 Facts.fetch(State.new(empty_store()), 100)

        assert rewards == %{}
      end
    end

    test "it returns the error when there's no key block" do
      with_mocks [{Db, [], [get_key_header: fn _height -> {:error, :chain_too_short} end]}] do
        assert {:error, :chain_too_short} = Facts.fetch(State.new(empty_store()), 100)
      end
    end
  end

  defp header(height) do
    height
    |> :aec_blocks.new_key(
      <<0::256>>,
      <<1::256>>,
      <<2::256>>,
      2,
      3,
      5_000,
      :default,
      1,
      @miner,
      @beneficiary
    )
    |> :aec_blocks.to_key_header()
  end

  defp put_block_reward(store, height, target_pk, amount) do
    store
    |> Store.put(
      Model.IntTransferTx,
      Model.int_transfer_tx(
        index: {{height, -1}, "reward_block", target_pk, -1},
        amount: amount
      )
    )
    |> Store.put(
      Model.KindIntTransferTx,
      Model.kind_int_transfer_tx(index: {"reward_block", {height, -1}, target_pk, -1})
    )
  end
end
