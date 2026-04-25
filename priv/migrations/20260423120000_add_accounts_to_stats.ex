defmodule AeMdw.Migrations.AddAccountsToStats do
  @moduledoc """
  Add the total number of accounts to the delta and total stats table.

  Uses a single forward scan of AccountCreation rather than loading micro-blocks
  through Mnesia, so memory use is O(num_key_blocks) and there are no aec_db calls
  per block.  When started from the application (from_start? = true) the heavy work
  is pushed to SyncingQueue so the API becomes available immediately.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  import Record

  require Model

  # Local records matching the OLD schema (without the new `accounts` field).
  # Used only for reading existing DB records in the migration.
  defrecord :delta_stat,
    index: 0,
    auctions_started: 0,
    names_activated: 0,
    names_expired: 0,
    names_revoked: 0,
    oracles_registered: 0,
    oracles_expired: 0,
    contracts_created: 0,
    block_reward: 0,
    dev_reward: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    channels_opened: 0,
    channels_closed: 0,
    locked_in_channels: 0

  defrecord :total_stat,
    index: 0,
    block_reward: 0,
    dev_reward: 0,
    total_supply: 0,
    active_auctions: 0,
    active_names: 0,
    inactive_names: 0,
    active_oracles: 0,
    inactive_oracles: 0,
    contracts: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    locked_in_channels: 0,
    open_channels: 0

  @dialyzer [
    # run/2 dispatches on a boolean guard that dialyzer can't fully see.
    {:no_match, run: 2},
    # delta_stat_mutation/3 pattern-matches the old (pre-migration) record shape
    # which dialyzer considers impossible once the model is updated.
    {:no_match, delta_stat_mutation: 3}
  ]

  @chunk_size 5_000
  @progress_key {:ae_mdw, :migration_progress, :add_accounts_to_stats}

  # Crash safety: the migration runner wraps async tasks so the version record in
  # Model.Migrations is written only after the task lambda returns. A crash, OOM,
  # or storage error during the task leaves the version unrecorded, so the
  # migration will re-run from scratch on the next boot.
  #
  # Idempotency: both phases detect already-updated records and overwrite them
  # with the recomputed value, so a partial run followed by a full re-run always
  # produces correct results.
  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()} | {:async, [fun()]}
  def run(state, true = _from_start?) do
    # Push heavy work onto SyncingQueue so the API starts immediately.
    # The migration runner defers writing the completion record until the task
    # lambda below returns.
    {:async, [fn -> do_run(state) end]}
  end

  def run(state, _from_start?) do
    {:ok, do_run(state)}
  end

  # ---------------------------------------------------------------------------
  # Core backfill logic
  # ---------------------------------------------------------------------------

  defp do_run(state) do
    set_progress(%{status: :running, phase: 1, processed: 0, total: nil})

    # Phase 1: scan Model.KeyBlockTime — pure RocksDB, no Mnesia calls.
    # Index is kb_time_msecs, so a forward scan is already time-ordered.
    # We need height-ordered pairs for Phase 3, so sort by height after.
    sorted_height_times =
      Model.KeyBlockTime
      |> RocksDbCF.stream(direction: :forward)
      |> Enum.map(fn Model.key_block_time(index: kb_time, height: height) ->
        {height, kb_time}
      end)
      |> Enum.sort_by(fn {height, _t} -> height end)

    n_heights = length(sorted_height_times)

    # Build a tuple of {kb_time, height} for O(1) indexed binary search.
    times_tuple =
      sorted_height_times
      |> Enum.map(fn {h, t} -> {t, h} end)
      |> List.to_tuple()

    n = tuple_size(times_tuple)

    set_progress(%{status: :running, phase: 2, processed: 0, total: nil})

    # Phase 2: single forward scan of AccountCreation.
    # For each account, binary-search its creation_time into the heights list
    # and increment that height's counter.  This completely replaces per-block
    # Mnesia (aec_db.find_block) calls from the previous implementation.
    delta_counts =
      Model.AccountCreation
      |> RocksDbCF.stream(direction: :forward)
      |> Enum.reduce(%{}, fn Model.account_creation(creation_time: t), acc ->
        case find_height_for_time(times_tuple, n, t) do
          nil -> acc
          height -> Map.update(acc, height, 1, &(&1 + 1))
        end
      end)

    set_progress(%{status: :running, phase: 3, processed: 0, total: n_heights})

    # Phase 3: write updated DeltaStat records in chunks.
    delta_count =
      sorted_height_times
      |> Stream.chunk_every(@chunk_size)
      |> Enum.reduce(0, fn chunk, total ->
        mutations =
          Enum.flat_map(chunk, fn {height, _kb_time} ->
            accounts = Map.get(delta_counts, height, 0)
            delta_stat_mutation(state, height, accounts)
          end)

        _state = State.commit_db(state, mutations)
        new_total = total + length(mutations)
        set_progress(%{status: :running, phase: 3, processed: new_total, total: n_heights})
        new_total
      end)

    set_progress(%{status: :running, phase: 4, processed: 0, total: n_heights})

    # Phase 4: sequential TotalStat accumulation.
    # Uses delta_counts directly so we don't depend on Phase 3 writes being
    # visible through the same state handle.
    # Mutations are committed in fixed-size chunks while streaming so we never
    # hold more than @chunk_size records in memory at once.
    total_stat_count =
      Model.TotalStat
      |> RocksDbCF.stream()
      |> Enum.reduce({0, 0, []}, fn record, {count_acc, written, buf} ->
        index = Model.total_stat(record, :index)
        delta_accounts = Map.get(delta_counts, index, 0)
        accounts_count = delta_accounts + count_acc

        # Records on disk may still be in the old 15-element format (no `accounts`
        # field). Tuple.append adds `accounts` at position 16 (the last field).
        # Already-migrated records have 16 elements and can be updated normally.
        new_total_stat =
          if tuple_size(record) == 15 do
            Tuple.append(record, accounts_count)
          else
            Model.total_stat(record, accounts: accounts_count)
          end

        buf = [WriteMutation.new(Model.TotalStat, new_total_stat) | buf]

        if length(buf) >= @chunk_size do
          _state = State.commit_db(state, buf)
          new_written = written + length(buf)
          set_progress(%{status: :running, phase: 4, processed: new_written, total: n_heights})
          {accounts_count, new_written, []}
        else
          {accounts_count, written, buf}
        end
      end)
      |> then(fn {_count_acc, written, buf} ->
        _state = State.commit_db(state, buf)
        written + length(buf)
      end)

    result = delta_count + total_stat_count
    set_progress(%{status: :done, phase: 4, processed: result, total: result})
    result
  end

  # ---------------------------------------------------------------------------
  # Progress tracking
  # ---------------------------------------------------------------------------

  defp set_progress(info) do
    :persistent_term.put(@progress_key, info)
  end

  # ---------------------------------------------------------------------------
  # DeltaStat mutation builder — handles old and new schema
  # ---------------------------------------------------------------------------

  defp delta_stat_mutation(state, height, accounts) do
    case State.get(state, Model.DeltaStat, height) do
      # Old schema (no `accounts` field) — reconstruct with accounts.
      {:ok,
       delta_stat(
         index: index,
         auctions_started: auctions_started,
         names_activated: names_activated,
         names_expired: names_expired,
         names_revoked: names_revoked,
         oracles_registered: oracle_registered,
         oracles_expired: oracles_expired,
         contracts_created: contracts_created,
         block_reward: block_reward,
         dev_reward: dev_reward,
         locked_in_auctions: locked_in_auctions,
         burned_in_auctions: burned_in_auctions,
         channels_opened: channels_opened,
         channels_closed: channels_closed,
         locked_in_channels: locked_in_channels
       )} ->
        new_record =
          Model.delta_stat(
            index: index,
            auctions_started: auctions_started,
            names_activated: names_activated,
            names_expired: names_expired,
            names_revoked: names_revoked,
            oracles_registered: oracle_registered,
            oracles_expired: oracles_expired,
            contracts_created: contracts_created,
            block_reward: block_reward,
            dev_reward: dev_reward,
            locked_in_auctions: locked_in_auctions,
            burned_in_auctions: burned_in_auctions,
            channels_opened: channels_opened,
            channels_closed: channels_closed,
            locked_in_channels: locked_in_channels,
            accounts: accounts
          )

        [WriteMutation.new(Model.DeltaStat, new_record)]

      # New schema — update the accounts field with the recomputed value.
      {:ok, Model.delta_stat() = existing} ->
        [WriteMutation.new(Model.DeltaStat, Model.delta_stat(existing, accounts: accounts))]

      :not_found ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Binary search helpers
  # ---------------------------------------------------------------------------

  # Returns the height h such that kb_time[h] <= t < kb_time[h+1].
  # Returns nil when t is before the first key block (genesis edge case).
  defp find_height_for_time(_times_tuple, 0, _t), do: nil

  defp find_height_for_time(times_tuple, n, t) do
    {first_time, _} = elem(times_tuple, 0)

    if t < first_time do
      nil
    else
      {_time, height} = elem(times_tuple, bsearch_upper(times_tuple, 0, n - 1, t))
      height
    end
  end

  # Returns the largest index i where times_tuple[i].time <= t.
  # Precondition: times_tuple[lo].time <= t (guaranteed by the caller).
  defp bsearch_upper(_tuple, lo, hi, _t) when lo >= hi, do: lo

  defp bsearch_upper(tuple, lo, hi, t) do
    # Upper mid avoids infinite loop when lo + 1 == hi.
    mid = div(lo + hi + 1, 2)
    {mid_time, _} = elem(tuple, mid)

    if mid_time <= t do
      bsearch_upper(tuple, mid, hi, t)
    else
      bsearch_upper(tuple, lo, mid - 1, t)
    end
  end
end
