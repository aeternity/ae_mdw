defmodule AeMdw.Sync.ServerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.AccountActivityMutation
  alias AeMdw.Db.AccountCreationMutation
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Db.TotalStatisticsMutation
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.EtsCache
  alias AeMdw.Node.ContractCallFixtures
  alias AeMdw.Node.Db
  alias AeMdw.Sync.Aex9AccountBalancesCache
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts
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
        sync(db_sync_data())
      end

      assert received(:built) == [1_000, 1_001]
      assert received(:broadcast) == expected_broadcasts(gens)
    end

    test "commits each generation in one transaction" do
      gens = [generation(1_000, 2), generation(1_001, 1)]

      with_mocks sync_mocks(gens) do
        sync(db_sync_data())
      end

      assert received(:committed) == [
               [{:mutation, {1_000, 0}}, {:mutation, {1_000, 1}}, {:mutation, {1_000, -1}}],
               [{:mutation, {1_001, 0}}, {:mutation, {1_001, -1}}]
             ]
    end

    test "commits the account mutations of a generation before its key block mutations" do
      gens = [generation(1_000, 2)]
      pubkeys = [<<1::256>>, <<2::256>>]
      trees = state_trees_with_accounts(pubkeys)

      with_mocks [
        {WealthRankAccounts, [],
         micro_block_accounts: fn _micro_block, _mutations -> MapSet.new(pubkeys) end},
        {:aec_db, [:passthrough],
         find_block_state_partial: fn _hash, true, [:accounts] -> {:value, trees} end},
        {Db, [:passthrough], get_block_time: fn _hash -> 0 end}
        | sync_mocks(gens)
      ] do
        sync(db_sync_data())
      end

      assert [
               [
                 {:mutation, {1_000, 0}},
                 {:mutation, {1_000, 1}}
                 | account_and_key_block_mutations
               ]
             ] = received(:committed)

      assert {:mutation, {1_000, -1}} = List.last(account_and_key_block_mutations)
      account_mutations = Enum.drop(account_and_key_block_mutations, -1)

      assert %{
               UpdateBalanceAccountMutation => 2,
               AccountCreationMutation => 2,
               AccountActivityMutation => 2
             } == Enum.frequencies_by(account_mutations, & &1.__struct__)
    end

    test "commits one update per statistic of a generation" do
      gens = [generation(1_000, 2)]
      micro_index = {{:blocks, :micro}, :day, 0}
      total_index = {{:total_transactions, :all}, :day, 0}

      gen_mutations = fn gen ->
        {height, blocks_mutations} = gen_mutations(gen)

        {height,
         Enum.map(blocks_mutations, fn
           {{_height, -1}, _key_block, _mutations} = key_block_mutations ->
             key_block_mutations

           {block_index, micro_block, mutations} ->
             statistics_mutations = [
               StatisticsMutation.new([{micro_index, 1}]),
               TotalStatisticsMutation.new([{total_index, 2}])
             ]

             {block_index, micro_block, [mutations, statistics_mutations]}
         end)}
      end

      with_mocks sync_mocks(gens, gen_mutations) do
        sync(db_sync_data())
      end

      assert [
               [
                 {:mutation, {1_000, 0}},
                 {:mutation, {1_000, 1}},
                 {:mutation, {1_000, -1}},
                 StatisticsMutation.new([{micro_index, 2}]),
                 TotalStatisticsMutation.new([{total_index, 4}])
               ]
             ] == received(:committed)
    end

    @tag :capture_log
    test "persists nothing of a generation whose commit fails" do
      key = :sync_server_test_uncommitted
      on_exit(fn -> Database.dirty_delete(Model.Stat, key) end)
      {key_block, [micro_block]} = generation(1_000, 1)
      write_mutation = WriteMutation.new(Model.Stat, Model.stat(index: key, payload: 0))
      failing_mutation = DeleteKeysMutation.new(%{})

      blocks_mutations = [
        {{1_000, 0}, micro_block, [write_mutation]},
        {{1_000, -1}, key_block, [failing_mutation]}
      ]

      with_mocks [
        {Block, [:passthrough],
         blocks_mutations: fn _from_height, _from_mbi, _from_txi, _to, _use_cache? ->
           [{1_000, blocks_mutations}]
         end},
        {DeleteKeysMutation, [:passthrough],
         execute: fn _mutation, _state -> raise "key block mutation failed" end}
      ] do
        {:next_state, {:syncing_db, ref}, _data} =
          Server.handle_event(:internal, :check_sync, :idle, db_sync_data())

        assert_receive {:DOWN, ^ref, :process, _pid,
                        {%RuntimeError{message: "key block mutation failed"}, _stacktrace}},
                       1_000
      end

      refute Database.exists?(Model.Stat, key)
    end

    test "resets the restart count after a generation syncs" do
      ref = make_ref()
      state_data = %Server{db_sync_data() | restarts: 4}

      assert {:next_state, :idle, %Server{restarts: 0}, _actions} =
               Server.handle_event(:info, {ref, state_at(1_000)}, {:syncing_db, ref}, state_data)
    end
  end

  describe "db sync of aex9 events" do
    setup do
      concurrency = Application.get_env(:ae_mdw, :sync_concurrency)
      on_exit(fn -> Application.put_env(:ae_mdw, :sync_concurrency, concurrency) end)
      Application.put_env(:ae_mdw, :sync_concurrency, 4)

      contract_pk = :crypto.strong_rand_bytes(32)

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      EtsCache.put(AeMdw.Contract, contract_pk, {{:fcode, functions, nil, nil}, nil, nil})

      {:ok,
       contract_pk: contract_pk,
       from_pk: :crypto.strong_rand_bytes(32),
       to_pk: :crypto.strong_rand_bytes(32),
       next_hashes: %{0 => :crypto.strong_rand_bytes(32), 1 => :crypto.strong_rand_bytes(32)}}
    end

    test "runs the balance dry-runs before the commit and drops them after it", ctx do
      %{contract_pk: contract_pk, from_pk: from_pk, to_pk: to_pk, next_hashes: next_hashes} = ctx

      with_mocks aex9_sync_mocks(ctx, fn _account_pk -> :ok end) do
        sync(db_sync_data())
      end

      assert [[{:ok, 10}, {:ok, 10}]] = received(:cached_at_commit)
      assert Enum.sort([{from_pk, 0}, {to_pk, 0}]) == Enum.sort(received(:dry_run))

      for account_pk <- [from_pk, to_pk] do
        assert :not_found =
                 Aex9AccountBalancesCache.get(contract_pk, {1_000, 0}, next_hashes[0], account_pk)
      end
    end

    test "dry-runs a balance only in the last block that refreshes it", ctx do
      %{from_pk: from_pk, to_pk: to_pk} = ctx
      other_pk = :crypto.strong_rand_bytes(32)
      transfers = [{0, from_pk, to_pk}, {1, from_pk, other_pk}]

      with_mocks aex9_sync_mocks(ctx, fn _account_pk -> :ok end, transfers) do
        sync(db_sync_data())
      end

      assert [[:not_found, {:ok, 10}, {:ok, 10}, {:ok, 10}]] = received(:cached_at_commit)
      assert Enum.sort([{to_pk, 0}, {from_pk, 1}, {other_pk, 1}]) == Enum.sort(received(:dry_run))

      assert [%{from_pk => {1_000, 1}, to_pk => {1_000, 0}, other_pk => {1_000, 1}}] ==
               received(:last_refresh_blocks_at_commit)
    end

    @tag :capture_log
    test "leaves a dry-run that fails to the commit, refreshing the account in every block",
         ctx do
      %{from_pk: from_pk, to_pk: to_pk} = ctx
      transfers = [{0, from_pk, to_pk}, {1, from_pk, to_pk}]

      dry_run_result = fn
        ^to_pk -> raise "dry-run crashed"
        _account_pk -> :ok
      end

      with_mocks aex9_sync_mocks(ctx, dry_run_result, transfers) do
        sync(db_sync_data())
      end

      assert [[:not_found, :not_found, {:ok, 10}, :not_found]] = received(:cached_at_commit)
      assert [%{from_pk => {1_000, 1}}] == received(:last_refresh_blocks_at_commit)
    end

    test "runs no dry-run before the commit with a concurrency of 1", ctx do
      Application.put_env(:ae_mdw, :sync_concurrency, 1)

      with_mocks aex9_sync_mocks(ctx, fn _account_pk -> :ok end) do
        sync(db_sync_data())
      end

      assert [[:not_found, :not_found]] = received(:cached_at_commit)
      assert [] == received(:dry_run)
    end

    test "gets the last refresh blocks with a concurrency of 1 too", ctx do
      %{from_pk: from_pk, to_pk: to_pk} = ctx
      Application.put_env(:ae_mdw, :sync_concurrency, 1)
      transfers = [{0, from_pk, to_pk}, {1, to_pk, from_pk}]

      with_mocks aex9_sync_mocks(ctx, fn _account_pk -> :ok end, transfers) do
        sync(db_sync_data())
      end

      assert [] == received(:dry_run)

      assert [%{from_pk => {1_000, 1}, to_pk => {1_000, 1}}] ==
               received(:last_refresh_blocks_at_commit)
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

  describe "mem sync on top of the synced overlay" do
    test "builds each generation once and broadcasts its blocks in order" do
      :persistent_term.put(:global_state, state_at(999))
      gens = [generation(999, 1), generation(1_000, 2)]

      with_mocks sync_mocks(gens) do
        assert <<1::256>> = sync(mem_sync_data())
      end

      assert received(:built) == [999, 1_000]
      assert received(:broadcast) == expected_broadcasts(gens)
    end

    test "resuming broadcasts the new blocks of the open generation and the next one" do
      :persistent_term.put(:global_state, state_at(1_000))
      gens = [generation(1_000, 1), generation(1_001, 2)]

      with_mocks [
        {:aec_chain, [:passthrough],
         find_common_ancestor: fn _hash1, _hash2 -> {:ok, <<2::256>>} end}
        | sync_mocks(gens)
      ] do
        assert <<1::256>> = sync(%Server{mem_sync_data() | mem_hash: <<2::256>>})
      end

      assert received(:built) == [1_000, 1_001]
      assert received(:broadcast) == expected_broadcasts(gens)
    end

    test "succeeds without broadcasting when there's nothing to sync" do
      :persistent_term.put(:global_state, state_at(999))

      with_mocks sync_mocks([]) do
        assert <<1::256>> = sync(mem_sync_data())
      end

      assert received(:built) == []
      assert received(:broadcast) == []
    end
  end

  defp db_sync_data do
    %Server{
      chain_height: 1_011,
      chain_hash: <<1::256>>,
      db_state: state_at(999),
      restarts: 0,
      rollback?: false
    }
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

  # One generation of two micro blocks with aex9 transfers {mbi, from_pk, to_pk},
  # by default one from from_pk to to_pk in the first micro block. The commit
  # reports which balances are cached and which last refresh blocks the state
  # holds at that point.
  defp aex9_sync_mocks(ctx, dry_run_result, transfers \\ nil) do
    %{contract_pk: contract_pk, from_pk: from_pk, to_pk: to_pk, next_hashes: next_hashes} = ctx
    transfers = transfers || [{0, from_pk, to_pk}]
    accounts = transfers |> Enum.flat_map(fn {_mbi, from, to} -> [from, to] end) |> Enum.uniq()
    mbis = Map.new(next_hashes, fn {mbi, next_hash} -> {next_hash, mbi} end)
    test_pid = self()
    kb_hash = :crypto.strong_rand_bytes(32)
    transfer_hash = :aec_hash.blake2b_256_hash("Transfer")
    fun_arg_res = %{arguments: [], function: "transfer", result: %{type: :unit, value: ""}}

    calls =
      transfers
      |> Enum.with_index(1)
      |> Enum.group_by(&elem(elem(&1, 0), 0), fn {{_mbi, from, to}, txi} ->
        log = {contract_pk, [transfer_hash, from, to, <<5::256>>], ""}
        call_rec = ContractCallFixtures.call_rec("logs", contract_pk, 1_000, nil, [log])

        ContractCallMutation.new(contract_pk, txi, fun_arg_res, call_rec)
      end)

    gen_mutations = fn gen ->
      {height, blocks_mutations} = gen_mutations(gen)

      {height,
       Enum.map(blocks_mutations, fn {{_height, mbi} = block_index, block, mutations} ->
         {block_index, block, Map.get(calls, mbi, []) ++ mutations}
       end)}
    end

    on_commit = fn state ->
      cached =
        Enum.flat_map(transfers, fn {mbi, from, to} ->
          Enum.map([from, to], fn account_pk ->
            Aex9AccountBalancesCache.get(contract_pk, {1_000, mbi}, next_hashes[mbi], account_pk)
          end)
        end)

      last_refresh_blocks =
        for account_pk <- accounts,
            {:ok, block_index} <-
              [State.cache_get(state, :aex9_last_refresh_blocks, {contract_pk, account_pk})],
            into: %{},
            do: {account_pk, block_index}

      send(test_pid, {:cached_at_commit, cached})
      send(test_pid, {:last_refresh_blocks_at_commit, last_refresh_blocks})
    end

    [
      {Db, [:passthrough],
       get_key_block_hash: fn 1_001 -> kb_hash end,
       get_next_hash: fn ^kb_hash, mbi -> Map.fetch!(next_hashes, mbi) end,
       aex9_balance: fn ^contract_pk, account_pk, {_type, _height, next_hash} = height_hash ->
         send(test_pid, {:dry_run, {account_pk, Map.fetch!(mbis, next_hash)}})
         :ok = dry_run_result.(account_pk)
         {:ok, {10, height_hash}}
       end}
      | sync_mocks([generation(1_000, 2)], gen_mutations, on_commit)
    ]
  end

  defp sync_mocks(gens, gen_mutations \\ &gen_mutations/1, on_commit \\ fn _state -> :ok end) do
    test_pid = self()

    [
      {Block, [:passthrough],
       blocks_mutations: fn _from_height, _from_mbi, _from_txi, _to, _use_cache? ->
         # Like the real stream, builds the generation again on every traversal.
         gens
         |> Enum.map(gen_mutations)
         |> Stream.map(fn {height, _blocks_mutations} = gen ->
           send(test_pid, {:built, height})
           gen
         end)
       end},
      {State, [:passthrough],
       create_mem_state: fn -> state_at(nil) end,
       commit_db: fn state, mutations, _clear_mem? ->
         on_commit.(state)
         send(test_pid, {:committed, mutations})
         state
       end,
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

  defp state_trees_with_accounts(pubkeys) do
    trees = :aec_trees.new_without_backend()

    accounts_tree =
      Enum.reduce(pubkeys, :aec_trees.accounts(trees), fn pubkey, accounts_tree ->
        pubkey |> :aec_accounts.new(10) |> :aec_accounts_trees.enter(accounts_tree)
      end)

    :aec_trees.set_accounts(trees, accounts_tree)
  end

  defp gen_mutations({key_block, micro_blocks}) do
    height = :aec_blocks.height(key_block)

    mbs_mutations =
      micro_blocks
      |> Enum.with_index()
      |> Enum.map(fn {micro_block, mbi} ->
        {{height, mbi}, micro_block, [{:mutation, {height, mbi}}]}
      end)

    {height, mbs_mutations ++ [{{height, -1}, key_block, [{:mutation, {height, -1}}]}]}
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
