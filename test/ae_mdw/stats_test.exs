defmodule AeMdw.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Error.Input
  alias AeMdw.Db.Store
  alias AeMdw.Stats
  alias AeMdw.TestSamples, as: TS

  require Model

  describe "fetch_stats/1" do
    test "it displays the max tps and miners_count" do
      key_block_hash = TS.key_block_hash(0)
      enc_hash = :aeser_api_encoder.encode(:key_block_hash, key_block_hash)

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {16.05, key_block_hash}))
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 20))
        |> State.new()

      assert {:ok,
              %{
                max_transactions_per_second: 16.05,
                max_transactions_per_second_block_hash: ^enc_hash,
                miners_count: 20
              }} = Stats.fetch_stats(state)
    end

    test "when not stat found, it returns an error" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      error_msg = "not found: no stats"

      assert {:error, %Input{message: ^error_msg}} = Stats.fetch_stats(state)
    end
  end
end
