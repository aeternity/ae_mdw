defmodule AeMdw.Migrations.AddIntCallAccountsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Migrations.AddIntCallAccounts
  alias AeMdw.Node.Db
  alias AeMdw.Stats

  import Mock

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(AddIntCallAccounts) do
    Code.require_file("priv/migrations/20261117120000_add_int_call_accounts.ex")
  end

  @height1 100_000_000
  @height2 @height1 + 1
  @height3 @height1 + 2
  @day 86_400_000
  # 2100-01-01, after the times of any other test
  @time1 4_102_444_800_000
  @time2 @time1 + 2 * @day
  @earlier_time @time1 - @day
  @later_time @time1 + 3 * @day
  @time3 @time1 + 4 * @day
  @add_accounts_to_stats_version 20_260_423_120_000
  @total_stats_cursor_key :add_int_call_accounts_total_stats

  setup do
    [new_pk, moved_pk, known_pk, contract_pk, removed_contract_pk] =
      for _i <- 1..5, do: :crypto.strong_rand_bytes(32)

    {txi1, txi2} = {2_000_000_000, 2_000_000_001}

    int_calls = [
      {{txi1, 0}, "Chain.spend", contract_pk, new_pk},
      {{txi1, 1}, "Chain.spend", contract_pk, moved_pk},
      # a contract whose protected clone failed is gone from the chain
      {{txi1, 2}, "Call.amount", removed_contract_pk, contract_pk},
      {{txi2, 0}, "Chain.spend", contract_pk, new_pk},
      {{txi2, 1}, "Chain.spend", contract_pk, known_pk}
    ]

    int_call_rows =
      Enum.flat_map(int_calls, fn {{txi, idx}, fname, sender_pk, recipient_pk} ->
        [
          {Model.IntContractCall,
           Model.int_contract_call(
             index: {txi, idx},
             fname: fname,
             tx: spend_aetx(sender_pk, recipient_pk)
           )},
          {Model.FnameIntContractCall, Model.fname_int_contract_call(index: {fname, txi, idx})}
        ]
      end)

    block_rows =
      for height <- [@height1, @height2],
          do: {Model.Block, Model.block(index: {height, 0}, hash: <<height::256>>)}

    rows =
      int_call_rows ++
        block_rows ++
        [
          # sync dates the accounts by the generation, not the transaction
          {Model.Tx, Model.tx(index: txi1, block_index: {@height1, 0}, time: @time1 - 1_000)},
          {Model.Tx, Model.tx(index: txi2, block_index: {@height2, 0}, time: @time2 - 1_000)},
          {Model.AccountCreation,
           Model.account_creation(index: moved_pk, creation_time: @later_time)},
          {Model.AccountBalance, Model.account_balance(index: moved_pk, balance: 5)},
          {Model.BalanceAccount, Model.balance_account(index: {5, moved_pk})},
          {Model.AccountCreation,
           Model.account_creation(index: known_pk, creation_time: @earlier_time)},
          {Model.AccountBalance, Model.account_balance(index: known_pk, balance: 3)},
          {Model.BalanceAccount, Model.balance_account(index: {3, known_pk})},
          # the moved account is counted at @height2, and from @height3 on in the totals
          {Model.DeltaStat, Model.delta_stat(index: @height1, accounts: 5)},
          {Model.DeltaStat, Model.delta_stat(index: @height2, accounts: 1)},
          {Model.TotalStat, Model.total_stat(index: @height1, accounts: 100)},
          {Model.TotalStat, Model.total_stat(index: @height2, accounts: 105)},
          {Model.TotalStat, Model.total_stat(index: @height3, accounts: 106)}
          | Enum.map(statistic_keys(:total_accounts, @later_time), fn key ->
              {Model.Statistic, Model.statistic(index: key, count: 1)}
            end)
        ]

    Enum.each(rows, fn {table, record} -> Database.dirty_write(table, record) end)

    # the app start records it on the empty test DB, unless it's still running
    migration = Database.fetch(Model.Migrations, @add_accounts_to_stats_version)

    if migration == :not_found do
      Database.dirty_write(
        Model.Migrations,
        Model.migrations(index: @add_accounts_to_stats_version, inserted_at: DateTime.utc_now())
      )
    end

    holders_count = holders_count()

    on_exit(fn ->
      Enum.each(rows, fn {table, record} -> Database.dirty_delete(table, elem(record, 1)) end)

      for pubkey <- [new_pk, moved_pk, known_pk] do
        Database.dirty_delete(Model.AccountCreation, pubkey)
        Database.dirty_delete(Model.AccountBalance, pubkey)
        Database.dirty_delete(Model.BalanceAccount, {10, pubkey})
      end

      for {pubkey, time} <- [
            {new_pk, @time1},
            {new_pk, @time2},
            {moved_pk, @time1},
            {known_pk, @time2}
          ] do
        Database.dirty_delete(Model.AccountActivity, {pubkey, time})
      end

      for tag <- [:total_accounts, :active_accounts],
          time <- [@time1, @time2, @later_time],
          key <- statistic_keys(tag, time) do
        Database.dirty_delete(Model.Statistic, key)
      end

      Database.dirty_delete(Model.Stat, @total_stats_cursor_key)

      Database.dirty_write(
        Model.Stat,
        Model.stat(index: Stats.holders_count_key(), payload: holders_count)
      )

      case migration do
        {:ok, record} -> Database.dirty_write(Model.Migrations, record)
        :not_found -> Database.dirty_delete(Model.Migrations, @add_accounts_to_stats_version)
      end
    end)

    %{
      new_pk: new_pk,
      moved_pk: moved_pk,
      known_pk: known_pk,
      contract_pk: contract_pk,
      removed_contract_pk: removed_contract_pk,
      holders_count: holders_count,
      trees: state_trees_with_accounts([new_pk, moved_pk, known_pk, contract_pk])
    }
  end

  test "adds the internal call accounts, without contracts, once", ctx do
    for _run <- 1..2 do
      assert {:ok, _count} = run_migration(ctx)

      assert_migrated(ctx, {[6, 1], [100, 106, 107]})
    end
  end

  test "completes the stats when rerun after a crash", ctx do
    # the balances are written after the stats and creations
    assert_raise RuntimeError, fn -> run_migration(ctx, :crash) end

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})
  end

  test "stops before writing when the node has no state for the synced block", ctx do
    assert_raise RuntimeError, ~r/no state for the last block of generation/, fn ->
      run_migration(ctx, :none)
    end

    state = State.new()

    assert :not_found = State.get(state, Model.AccountCreation, ctx.new_pk)

    assert {:ok, Model.account_creation(creation_time: @later_time)} =
             State.get(state, Model.AccountCreation, ctx.moved_pk)

    assert 0 == statistic_count(state, :active_accounts, @time1)
    assert 5 == state |> State.fetch!(Model.DeltaStat, @height1) |> Model.delta_stat(:accounts)
    assert :not_found = State.get(state, Model.Stat, @total_stats_cursor_key)

    assert [100, 105, 106] ==
             Enum.map([@height1, @height2, @height3], fn height ->
               state |> State.fetch!(Model.TotalStat, height) |> Model.total_stat(:accounts)
             end)

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})
  end

  test "resumes the total stats from the cursor", ctx do
    # as left by a crash after adjusting the @height2 total stats
    Database.dirty_write(Model.TotalStat, Model.total_stat(index: @height2, accounts: 106))
    write_total_stats_cursor(@height3)

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})
  end

  test "resumes the total stats after a crash in their walk, adding each delta once", ctx do
    # two rows more than a chunk, as the walk starts at @height2
    extra_heights = (@height3 + 1)..(@height3 + 1_000)

    for height <- extra_heights do
      Database.dirty_write(Model.TotalStat, Model.total_stat(index: height, accounts: 200))
    end

    on_exit(fn -> Enum.each(extra_heights, &Database.dirty_delete(Model.TotalStat, &1)) end)

    # the first chunk ends at @height3 + 998, the crash hits the second row of the next one
    next_height = @height3 + 999

    assert_raise RuntimeError, fn ->
      run_migration(ctx, {:crash_total_stat, next_height + 1})
    end

    state = State.new()

    assert {:ok, Model.stat(payload: ^next_height)} =
             State.get(state, Model.Stat, @total_stats_cursor_key)

    assert [201, 200, 200] ==
             Enum.map((next_height - 1)..(next_height + 1), &total_accounts(state, &1))

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})
    state = State.new()
    assert [201] == extra_heights |> Enum.map(&total_accounts(state, &1)) |> Enum.uniq()
  end

  test "adds the remaining creations without adding to the total stats again", ctx do
    # as left by a crash after the total stats and a first chunk of creations
    for {height, accounts} <- [{@height2, 106}, {@height3, 107}] do
      Database.dirty_write(Model.TotalStat, Model.total_stat(index: height, accounts: accounts))
    end

    write_total_stats_cursor(@height3 + 1)

    _state =
      State.new()
      |> State.put(
        Model.AccountCreation,
        Model.account_creation(index: ctx.moved_pk, creation_time: @time1)
      )
      |> SyncStats.increment_statistics(:total_accounts, @later_time, -1)
      |> SyncStats.increment_statistics(:total_accounts, @time1, 1)

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})
  end

  test "leaves the delta and total stats to a pending AddAccountsToStats", ctx do
    Database.dirty_delete(Model.Migrations, @add_accounts_to_stats_version)

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[5, 1], [100, 105, 106]})
  end

  test "adds the accounts of a half-synced last generation without their stats", ctx do
    # older versions committed each block, so a stop could leave @height3 without its stats
    pubkey = :crypto.strong_rand_bytes(32)
    txi = 2_000_000_002

    rows = [
      {Model.Block, Model.block(index: {@height3, 0}, hash: <<@height3::256>>)},
      {Model.Tx, Model.tx(index: txi, block_index: {@height3, 0}, time: @time3 - 1_000)},
      {Model.IntContractCall,
       Model.int_contract_call(
         index: {txi, 0},
         fname: "Chain.spend",
         tx: spend_aetx(ctx.contract_pk, pubkey)
       )},
      {Model.FnameIntContractCall, Model.fname_int_contract_call(index: {"Chain.spend", txi, 0})}
    ]

    Enum.each(rows, fn {table, record} -> Database.dirty_write(table, record) end)

    on_exit(fn ->
      Enum.each(rows, fn {table, record} -> Database.dirty_delete(table, elem(record, 1)) end)
      Database.dirty_delete(Model.AccountCreation, pubkey)
      Database.dirty_delete(Model.AccountActivity, {pubkey, @time3})

      for tag <- [:total_accounts, :active_accounts], key <- statistic_keys(tag, @time3) do
        Database.dirty_delete(Model.Statistic, key)
      end
    end)

    assert {:ok, _count} = run_migration(ctx)

    assert_migrated(ctx, {[6, 1], [100, 106, 107]})

    state = State.new()

    assert {:ok, Model.account_creation(creation_time: @time3)} =
             State.get(state, Model.AccountCreation, pubkey)

    assert :not_found = State.get(state, Model.DeltaStat, @height3)
  end

  defp run_migration(%{contract_pk: contract_pk, trees: trees}, node_state \\ :found) do
    gen_times = %{
      <<@height1::256>> => @time1,
      <<@height2::256>> => @time2,
      <<@height3::256>> => @time3
    }

    find_block_state_partial =
      case node_state do
        :none -> fn _block_hash, true, [:accounts] -> :none end
        _found -> fn <<@height2::256>>, true, [:accounts] -> {:value, trees} end
      end

    crash_mocks =
      case node_state do
        :crash ->
          [
            {UpdateBalanceAccountMutation, [:passthrough],
             execute: fn _mutation, _state -> raise "balance write failed" end}
          ]

        {:crash_total_stat, crash_height} ->
          [
            {State, [:passthrough],
             update!: fn
               _state, Model.TotalStat, ^crash_height, _fun -> raise "total stat write failed"
               state, table, key, fun -> :meck.passthrough([state, table, key, fun])
             end}
          ]

        _no_crash ->
          []
      end

    with_mocks [
      {Contract, [], exists?: &(&1 == contract_pk)},
      {Db, [:passthrough], get_block_time: &Map.fetch!(gen_times, &1)},
      {:aec_db, [:passthrough], find_block_state_partial: find_block_state_partial}
      | crash_mocks
    ] do
      AddIntCallAccounts.run(State.new(), false)
    end
  end

  defp assert_migrated(ctx, {deltas_accounts, totals_accounts}) do
    %{new_pk: new_pk, moved_pk: moved_pk, known_pk: known_pk} = ctx
    state = State.new()

    for {pubkey, creation_time} <- [
          {new_pk, @time1},
          {moved_pk, @time1},
          {known_pk, @earlier_time}
        ] do
      assert {:ok, Model.account_creation(creation_time: ^creation_time)} =
               State.get(state, Model.AccountCreation, pubkey)

      assert {:ok, Model.account_balance(balance: 10)} =
               State.get(state, Model.AccountBalance, pubkey)
    end

    for old_balance_key <- [{5, moved_pk}, {3, known_pk}] do
      assert :not_found = State.get(state, Model.BalanceAccount, old_balance_key)
    end

    # the moved and the known accounts already held AE
    assert ctx.holders_count + 1 == holders_count()

    assert 2 == statistic_count(state, :total_accounts, @time1)
    assert 0 == statistic_count(state, :total_accounts, @time2)
    assert 0 == statistic_count(state, :total_accounts, @later_time)
    assert 2 == statistic_count(state, :active_accounts, @time1)
    assert 2 == statistic_count(state, :active_accounts, @time2)

    assert deltas_accounts ==
             Enum.map([@height1, @height2], fn height ->
               state |> State.fetch!(Model.DeltaStat, height) |> Model.delta_stat(:accounts)
             end)

    assert totals_accounts ==
             Enum.map([@height1, @height2, @height3], fn height ->
               state |> State.fetch!(Model.TotalStat, height) |> Model.total_stat(:accounts)
             end)

    assert :not_found = State.get(state, Model.Stat, @total_stats_cursor_key)

    for pubkey <- [ctx.contract_pk, ctx.removed_contract_pk],
        table <- [Model.AccountCreation, Model.AccountBalance] do
      assert :not_found = State.get(state, table, pubkey)
    end
  end

  defp total_accounts(state, height),
    do: state |> State.fetch!(Model.TotalStat, height) |> Model.total_stat(:accounts)

  defp write_total_stats_cursor(next_height) do
    Database.dirty_write(
      Model.Stat,
      Model.stat(index: @total_stats_cursor_key, payload: next_height)
    )
  end

  defp spend_aetx(sender_pk, recipient_pk) do
    {:ok, aetx} =
      :aec_spend_tx.new(%{
        sender_id: :aeser_id.create(:account, sender_pk),
        recipient_id: :aeser_id.create(:account, recipient_pk),
        amount: 1,
        fee: 0,
        nonce: 0,
        payload: <<>>
      })

    aetx
  end

  defp state_trees_with_accounts(pubkeys) do
    trees = :aec_trees.new_without_backend()

    accounts_tree =
      Enum.reduce(pubkeys, :aec_trees.accounts(trees), fn pubkey, accounts_tree ->
        pubkey |> :aec_accounts.new(10) |> :aec_accounts_trees.enter(accounts_tree)
      end)

    :aec_trees.set_accounts(trees, accounts_tree)
  end

  defp statistic_keys(tag, time) do
    time
    |> SyncStats.time_intervals()
    |> Enum.map(fn {interval_by, interval_start} -> {tag, interval_by, interval_start} end)
  end

  defp statistic_count(state, tag, time) do
    [day_key | _week_and_month_keys] = statistic_keys(tag, time)

    case State.get(state, Model.Statistic, day_key) do
      {:ok, Model.statistic(count: count)} -> count
      :not_found -> 0
    end
  end

  defp holders_count do
    case State.get(State.new(), Model.Stat, Stats.holders_count_key()) do
      {:ok, Model.stat(payload: count)} -> count
      :not_found -> 0
    end
  end
end
