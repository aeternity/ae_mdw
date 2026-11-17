defmodule AeMdw.Migrations.AddIntCallAccounts do
  @moduledoc """
  Sync missed the accounts reached only through Chain.spend internal calls, so
  they had no balance, creation or activity. Adds them from the indexed internal
  calls, without contracts, like sync now does.

  Only adds the new accounts to the delta and total stats: rerunning
  AddAccountsToStats would also drop the protocol accounts from them, as it
  skips their 1970 creation times. Accounts it dates earlier keep their delta
  and total stats, as AddAccountsToStats counted a generation's accounts at its
  own height and sync counts them at the next one.

  Runs before syncing starts, so no block touches these accounts meanwhile. A
  rerun after a crash skips the creations already written and resumes the
  total stats from a cursor.
  """

  alias AeMdw.Accounts
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Node.Db
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts

  require Model

  @chunk_size 1_000
  @add_accounts_to_stats_version 20_260_423_120_000
  @total_stats_cursor_key :add_int_call_accounts_total_stats

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    first_seen =
      state
      |> int_call_accounts()
      |> Enum.reduce(%{}, fn {pubkey, time, height}, first_seen ->
        Map.update(first_seen, pubkey, {time, height}, &min(&1, {time, height}))
      end)
      |> Map.reject(fn {pubkey, _time_height} -> Contract.exists?(pubkey) end)

    if map_size(first_seen) == 0 do
      {:ok, 0}
    else
      # before any write, so a missing node state leaves the DB as it was
      balances = node_balances(state, first_seen)
      creations = creation_changes(state, first_seen)

      # until AddAccountsToStats is recorded, these stats may lack the accounts field, and it
      # rewrites them anyway
      stats? =
        match?(
          {:ok, _migration},
          State.get(state, Model.Migrations, @add_accounts_to_stats_version)
        )

      # before the creations, as a rerun finds the same ones only until they're written
      total_stats_count = if stats?, do: add_to_total_stats(state, creations), else: 0
      creations_count = add_creations(creations, stats?, State.height(state))
      activities_count = add_activities(state, first_seen)
      balances_count = update_balances(balances)
      _state = State.delete(state, Model.Stat, @total_stats_cursor_key)

      {:ok, total_stats_count + creations_count + activities_count + balances_count}
    end
  end

  defp int_call_accounts(state) do
    WealthRankAccounts.int_call_fnames()
    |> Stream.flat_map(fn fname ->
      key_boundary =
        Collection.generate_key_boundary({fname, Collection.integer(), Collection.integer()})

      Collection.stream(state, Model.FnameIntContractCall, :forward, key_boundary, nil)
    end)
    # sync takes the time of the generation's last micro block
    |> Stream.transform(nil, fn {_fname, call_txi, local_idx}, gen_time ->
      Model.int_contract_call(tx: aetx) =
        State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

      Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, call_txi)

      {_height, time} =
        gen_time =
        case gen_time do
          {^height, _time} -> gen_time
          _other_gen -> {height, state |> last_block_hash(height) |> Db.get_block_time()}
        end

      accounts = aetx |> WealthRankAccounts.aetx_accounts() |> Enum.map(&{&1, time, height})

      {accounts, gen_time}
    end)
  end

  defp creation_changes(state, first_seen) do
    Enum.flat_map(first_seen, fn {pubkey, {time, height}} ->
      case State.get(state, Model.AccountCreation, pubkey) do
        {:ok, Model.account_creation(creation_time: old_time)} when old_time <= time ->
          []

        {:ok, Model.account_creation(creation_time: old_time)} ->
          [{pubkey, time, height, old_time}]

        :not_found ->
          [{pubkey, time, height, nil}]
      end
    end)
  end

  # as in StatsMutation, TotalStat(h + 1) adds DeltaStat(h)
  defp add_to_total_stats(state, creations) do
    deltas =
      creations
      |> Enum.flat_map(fn
        {_pubkey, _time, height, nil} -> [height]
        _moved_creation -> []
      end)
      |> Enum.frequencies()
      |> Enum.sort()

    case deltas do
      [] ->
        0

      [{first_height, _delta} | _deltas] ->
        from_height =
          case State.get(state, Model.Stat, @total_stats_cursor_key) do
            {:ok, Model.stat(payload: next_height)} -> next_height
            :not_found -> first_height + 1
          end

        state
        |> State.stream(Model.TotalStat, :forward, from_height)
        |> Stream.transform({deltas, 0}, fn height, {deltas, added} ->
          {lower_deltas, deltas} =
            Enum.split_while(deltas, fn {delta_height, _delta} -> delta_height < height end)

          added = Enum.reduce(lower_deltas, added, fn {_height, delta}, sum -> sum + delta end)

          {[{height, added}], {deltas, added}}
        end)
        |> write_in_chunks(
          fn {height, added}, state ->
            State.update!(state, Model.TotalStat, height, fn total_stat ->
              accounts = Model.total_stat(total_stat, :accounts)
              Model.total_stat(total_stat, accounts: accounts + added)
            end)
          end,
          fn state, chunk ->
            {last_height, _added} = List.last(chunk)
            cursor = Model.stat(index: @total_stats_cursor_key, payload: last_height + 1)

            State.put(state, Model.Stat, cursor)
          end
        )
    end
  end

  defp add_creations(creations, stats?, synced_height) do
    write_in_chunks(creations, fn
      {pubkey, time, height, nil}, state ->
        state = Accounts.maybe_increase_creation_statistics(state, pubkey, time)

        # sync recounts a generation that an older version left half-synced
        if stats? and height <= synced_height do
          # at height, as AddAccountsToStats did; sync would count it at height + 1
          State.update!(state, Model.DeltaStat, height, fn delta_stat ->
            accounts = Model.delta_stat(delta_stat, :accounts)
            Model.delta_stat(delta_stat, accounts: accounts + 1)
          end)
        else
          state
        end

      {pubkey, time, _height, old_time}, state ->
        state
        |> State.put(
          Model.AccountCreation,
          Model.account_creation(index: pubkey, creation_time: time)
        )
        |> SyncStats.increment_statistics(:total_accounts, old_time, -1)
        |> SyncStats.increment_statistics(:total_accounts, time, 1)
    end)
  end

  defp add_activities(state, first_seen) do
    state
    |> int_call_accounts()
    |> Stream.filter(fn {pubkey, _time, _height} -> Map.has_key?(first_seen, pubkey) end)
    # a generation's calls often pay the same account
    |> Stream.dedup()
    |> write_in_chunks(fn {pubkey, time, _height}, state ->
      Accounts.account_activity(state, pubkey, time)
    end)
  end

  defp node_balances(state, first_seen) do
    height = State.height(state)
    block_hash = last_block_hash(state, height)

    case :aec_db.find_block_state_partial(block_hash, true, [:accounts]) do
      {:value, trees} ->
        accounts_tree = :aec_trees.accounts(trees)

        Enum.flat_map(first_seen, fn {pubkey, _time_height} ->
          case :aec_accounts_trees.lookup(pubkey, accounts_tree) do
            {:value, account} -> [{pubkey, :aec_accounts.balance(account)}]
            :none -> []
          end
        end)

      :none ->
        raise "the node has no state for the last block of generation #{height}, " <>
                "the last one mdw synced"
    end
  end

  defp update_balances(balances) do
    write_in_chunks(balances, fn {pubkey, balance}, state ->
      UpdateBalanceAccountMutation.execute(
        UpdateBalanceAccountMutation.new(pubkey, balance),
        state
      )
    end)
  end

  defp last_block_hash(state, height) do
    {:ok, block_index} = State.prev(state, Model.Block, {height + 1, -1})
    Model.block(hash: block_hash) = State.fetch!(state, Model.Block, block_index)

    block_hash
  end

  defp write_in_chunks(enum, write_fn, chunk_fn \\ fn state, _chunk -> state end) do
    enum
    |> Stream.chunk_every(@chunk_size)
    |> Enum.reduce(0, fn chunk, count ->
      _state =
        TxnDbStore.transaction(fn store ->
          chunk |> Enum.reduce(State.new(store), write_fn) |> chunk_fn.(chunk)
        end)

      count + length(chunk)
    end)
  end
end
