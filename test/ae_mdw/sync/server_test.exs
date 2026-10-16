defmodule AeMdw.Sync.ServerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Sync.MemStoreCreator
  alias AeMdw.Sync.Server
  alias AeMdwWeb.Websocket.Broadcaster

  import Mock

  require Model

  setup do
    saved =
      Enum.map([:global_state, {Server, :syncing?}], &{&1, :persistent_term.get(&1, :none)})

    on_exit(fn ->
      Enum.each(saved, fn
        {key, :none} -> :persistent_term.erase(key)
        {key, value} -> :persistent_term.put(key, value)
      end)
    end)
  end

  describe "db sync" do
    test "builds each generation once and broadcasts its blocks in order" do
      gens = [generation(1_000, 2), generation(1_001, 1)]

      with_mocks sync_mocks(gens) do
        sync(%Server{
          chain_height: 1_011,
          chain_hash: <<1::256>>,
          db_state: state_at(999),
          restarts: 0,
          rollback?: false
        })
      end

      assert received(:built) == [1_000, 1_001]
      assert received(:broadcast) == expected_broadcasts(gens)
    end
  end

  describe "mem sync rebuilding the overlay" do
    setup do
      :persistent_term.put(:global_state, state_at(1_005))
      :ok
    end

    test "builds each generation once and broadcasts its blocks in order" do
      gens = [generation(999, 1), generation(1_000, 2)]

      with_mocks sync_mocks(gens) do
        assert <<1::256>> = sync(mem_sync_data())
      end

      assert received(:built) == [999, 1_000]
      assert received(:broadcast) == expected_broadcasts(gens)
    end

    test "succeeds without broadcasting when there's nothing to sync" do
      with_mocks sync_mocks([]) do
        assert <<1::256>> = sync(mem_sync_data())
      end

      assert received(:built) == []
      assert received(:broadcast) == []
    end
  end

  defp mem_sync_data do
    %Server{
      chain_height: 1_009,
      chain_hash: <<1::256>>,
      db_state: state_at(999),
      restarts: 0,
      rollback?: false
    }
  end

  defp sync(state_data) do
    {:next_state, {_syncing, ref}, _data} =
      Server.handle_event(:internal, :check_sync, :idle, state_data)

    assert_receive {^ref, result}, 1_000
    Process.demonitor(ref, [:flush])

    result
  end

  defp sync_mocks(gens) do
    test_pid = self()

    [
      {Block, [:passthrough],
       blocks_mutations: fn _from_height, _from_mbi, _from_txi, _to, _use_cache? ->
         # Like the real stream, builds the generation again on every traversal.
         gens
         |> Enum.map(&gen_mutations/1)
         |> Stream.map(fn {height, _blocks_mutations} = gen ->
           send(test_pid, {:built, height})
           gen
         end)
       end},
      {State, [:passthrough],
       create_mem_state: fn -> state_at(nil) end,
       commit_db: fn state, _mutations, _clear_mem? -> state end,
       commit_mem: fn state, _mutations -> state end},
      {MemStoreCreator, [:passthrough], commit: fn _store -> :ok end},
      {Broadcaster, [:passthrough],
       broadcast_key_block: fn block, version, source, mbs_count, txs_count ->
         send(test_pid, {:broadcast, {:key_block, block, version, source, mbs_count, txs_count}})
         :ok
       end,
       broadcast_micro_block: fn block, source ->
         send(test_pid, {:broadcast, {:micro_block, block, source}})
         :ok
       end,
       broadcast_txs: fn block, source ->
         send(test_pid, {:broadcast, {:txs, block, source}})
         :ok
       end}
    ]
  end

  defp state_at(height) do
    state = NullStore.new() |> MemStore.new() |> State.new()

    if height,
      do: State.put(state, Model.DeltaStat, Model.delta_stat(index: height)),
      else: state
  end

  defp generation(height, mbs_count) do
    key_block =
      :aec_blocks.new_key(
        height,
        <<0::256>>,
        <<0::256>>,
        <<0::256>>,
        0,
        0,
        0,
        :default,
        1,
        <<0::256>>,
        <<0::256>>
      )

    micro_blocks =
      Enum.map(1..mbs_count, fn i ->
        :aec_blocks.new_micro(height, <<i::256>>, <<0::256>>, <<>>, <<>>, [], 0, :no_fraud, 0)
      end)

    {key_block, micro_blocks}
  end

  defp gen_mutations({key_block, micro_blocks}) do
    height = :aec_blocks.height(key_block)

    mbs_mutations =
      micro_blocks
      |> Enum.with_index()
      |> Enum.map(fn {micro_block, mbi} -> {{height, mbi}, micro_block, []} end)

    {height, mbs_mutations ++ [{{height, -1}, key_block, []}]}
  end

  defp expected_broadcasts(gens) do
    Enum.flat_map(gens, fn {key_block, micro_blocks} ->
      Enum.map([:v1, :v2, :v3], &{:key_block, key_block, &1, :mdw, length(micro_blocks), 0}) ++
        Enum.flat_map(micro_blocks, &[{:micro_block, &1, :mdw}, {:txs, &1, :mdw}])
    end)
  end

  defp received(tag) do
    receive do
      {^tag, message} -> [message | received(tag)]
    after
      0 -> []
    end
  end
end
