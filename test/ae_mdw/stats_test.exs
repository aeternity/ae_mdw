defmodule AeMdw.StatsTest do
  use ExUnit.Case
  import Mock

  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Error.Input
  alias AeMdw.Stats
  alias AeMdw.TestSamples, as: TS

  require Model

  describe "fetch_stats/1" do
    test "it displays the max tps and miners_count" do
      key_block_hash = TS.key_block_hash(0)
      enc_hash = :aeser_api_encoder.encode(:key_block_hash, key_block_hash)
      now = :aeu_time.now_in_msecs()
      three_minutes = 3 * 60 * 1000

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.Stat, Model.stat(index: :max_tps, payload: {16.05, key_block_hash}))
        |> State.put(Model.Stat, Model.stat(index: :miners_count, payload: 20))
        |> State.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> State.put(Model.Block, Model.block(index: {10, -1}, hash: key_block_hash))

      with_mocks([
        {:aec_chain, [],
         get_key_block_by_height: fn
           1 -> {:ok, :first_block}
           _n -> {:ok, :other_block}
         end},
        {:aec_blocks, [],
         time_in_msecs: fn
           :first_block -> now - 10 * three_minutes
           :other_block -> now
         end}
      ]) do
        assert {:ok,
                %{
                  max_transactions_per_second: 16.05,
                  max_transactions_per_second_block_hash: ^enc_hash,
                  miners_count: 20,
                  ms_per_block: ^three_minutes
                }} = Stats.fetch_stats(state)
      end
    end

    test "when not stat found, it returns an error" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> State.put(Model.Block, Model.block(index: {10, -1}, hash: <<10::256>>))

      error_msg = "not found: no stats"

      with_mocks([
        {:aec_chain, [],
         get_key_block_by_height: fn
           1 -> {:ok, :first_block}
           _n -> {:ok, :other_block}
         end},
        {:aec_blocks, [],
         time_in_msecs: fn
           :first_block -> 1
           :other_block -> 10
         end}
      ]) do
        assert {:error, %Input{message: ^error_msg}} = Stats.fetch_stats(state)
      end
    end
  end
end
