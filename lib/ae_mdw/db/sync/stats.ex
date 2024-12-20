defmodule AeMdw.Db.Sync.Stats do
  @moduledoc """
  Update general and per contract stats during the syncing process.
  """

  alias AeMdw.Aex9
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Stats
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep template_id :: AeMdw.Aex141.template_id()
  @typep aexn_type :: :aex9 | :aex141
  @typep time() :: Blocks.time()
  @typep type_counts() :: %{Node.tx_type() => pos_integer()}
  @typep height() :: Blocks.height()
  @typep txi() :: Txs.txi()
  @typep interval_by() :: Stats.interval_by()
  @typep intervals() :: [{interval_by(), time()}]

  @start_unix 1_970
  @seconds_per_day 3_600 * 24

  @spec update_nft_stats(State.t(), pubkey(), nil | pubkey(), nil | pubkey()) :: State.t()
  def update_nft_stats(state, contract_pk, prev_owner_pk, to_pk) do
    state
    |> increment_collection_nfts(contract_pk, prev_owner_pk)
    |> decrement_collection_owners(contract_pk, prev_owner_pk)
    |> increment_collection_owners(contract_pk, to_pk)
  end

  @spec increment_contract_count(State.t(), aexn_type()) :: State.t()
  def increment_contract_count(state, aexn_type),
    do: update_stat_counter(state, Stats.aexn_count_key(aexn_type))

  @spec increment_aex9_holders(State.t(), pubkey()) :: State.t()
  def increment_aex9_holders(state, contract_pk),
    do: update_stat_counter(state, Stats.aex9_holder_count_key(contract_pk))

  @spec decrement_aex9_holders(State.t(), pubkey(), txi()) :: State.t()
  def decrement_aex9_holders(state, contract_pk, txi) do
    update_fn = fn x ->
      new_count = x - 1

      _ignored_result =
        if new_count < 0 do
          State.put(
            state,
            Model.AexnInvalidContract,
            Model.aexn_invalid_contract(
              index: {:aex9, contract_pk},
              reason: Aex9.invalid_number_of_holders_reason(),
              description: "Invalid amount of holders on txi #{txi}"
            )
          )
        end

      new_count
    end

    update_stat_counter(state, Stats.aex9_holder_count_key(contract_pk), update_fn)
  end

  @spec increment_aex9_logs(State.t(), pubkey()) :: State.t()
  def increment_aex9_logs(state, contract_pk),
    do: update_stat_counter(state, Stats.aex9_logs_count_key(contract_pk))

  @spec increment_nft_template_tokens(State.t(), pubkey(), template_id()) :: State.t()
  def increment_nft_template_tokens(state, contract_pk, template_id),
    do: update_stat_counter(state, Stats.nft_template_tokens_key(contract_pk, template_id))

  @spec decrement_nft_template_tokens(State.t(), pubkey(), template_id()) :: State.t()
  def decrement_nft_template_tokens(state, contract_pk, template_id),
    do:
      update_stat_counter(
        state,
        Stats.nft_template_tokens_key(contract_pk, template_id),
        &(&1 - 1)
      )

  @spec key_block_mutations(height(), Db.key_block(), [Db.micro_block()], txi(), txi(), boolean()) ::
          [Mutation.t()]
  def key_block_mutations(height, key_block, micro_blocks, from_txi, next_txi, starting_from_mb0?) do
    header = :aec_blocks.to_header(key_block)
    time = :aec_headers.time_in_msecs(header)
    difficulty = :aec_blocks.difficulty(key_block)
    hashrate = Node.difficulty_to_hashrate(difficulty)
    {:ok, key_hash} = :aec_headers.hash_header(header)

    statistics =
      time
      |> time_intervals()
      |> Enum.flat_map(fn {interval, interval_start} ->
        [
          {{{:blocks, :key}, interval, interval_start}, 1},
          {{{:blocks, :all}, interval, interval_start}, 1},
          {{:difficulty, interval, interval_start}, difficulty},
          {{:hashrate, interval, interval_start}, hashrate}
        ]
      end)

    {_last_time, total_time, total_txs} =
      Enum.reduce(micro_blocks, {time, 0, 0}, fn micro_block, {last_time, time_acc, count_acc} ->
        header = :aec_blocks.to_header(micro_block)
        time = :aec_headers.time_in_msecs(header)
        count = length(:aec_blocks.txs(micro_block))

        {time, time_acc + time - last_time, count_acc + count}
      end)

    tps = if total_time > 0, do: round(total_txs * 100_000 / total_time) / 100, else: 0

    [
      StatsMutation.new(height, key_hash, from_txi, next_txi, tps, starting_from_mb0?, time),
      StatisticsMutation.new(statistics)
    ]
  end

  @spec micro_block_mutations(time(), type_counts()) :: StatisticsMutation.t() | nil
  def micro_block_mutations(time, type_counts) do
    intervals = time_intervals(time)

    total_count =
      Enum.reduce(type_counts, 0, fn {_tx_type, increment}, acc -> acc + increment end)

    mb_statistics =
      Enum.flat_map(intervals, fn {interval, interval_start} ->
        [
          {{{:blocks, :micro}, interval, interval_start}, 1},
          {{{:blocks, :all}, interval, interval_start}, 1}
        ]
      end)

    txs_statistics =
      if total_count > 0 do
        Enum.flat_map(intervals, fn {interval, interval_start} ->
          tx_type_statistics =
            Enum.map(type_counts, fn {tx_type, count} ->
              {{{:transactions, tx_type}, interval, interval_start}, count}
            end)

          total_statistic = {{{:transactions, :all}, interval, interval_start}, total_count}

          [total_statistic | tx_type_statistics]
        end)
      else
        []
      end

    StatisticsMutation.new(mb_statistics ++ txs_statistics)
  end

  @spec time_intervals(time()) :: intervals()
  def time_intervals(time) do
    seconds = div(time, 1_000)
    %DateTime{year: year, month: month} = DateTime.from_unix!(seconds)
    day_start = div(seconds, @seconds_per_day)
    week_start = div(day_start, 7)
    month_start = (year - @start_unix) * 12 + month - 1

    [
      {:day, day_start},
      {:week, week_start},
      {:month, month_start}
    ]
  end

  @spec key_boundaries_for_intervals(pubkey(), intervals()) :: [
          {interval_by(), {{pubkey(), pos_integer()}, {pubkey(), pos_integer()}}}
        ]
  def key_boundaries_for_intervals(pk, day: day_start, week: week_start, month: _month_start) do
    initial_seconds = day_start * @seconds_per_day
    %DateTime{year: year, month: month} = DateTime.from_unix!(initial_seconds)

    month_start =
      year
      |> Date.new!(month, 1)
      |> DateTime.new!(Time.new!(0, 0, 0))
      |> DateTime.to_unix()

    {new_year, new_month} =
      case month do
        12 -> {year + 1, 1}
        _another_month -> {year, month + 1}
      end

    next_month_start =
      new_year
      |> Date.new!(new_month, 1)
      |> DateTime.new!(Time.new!(0, 0, 0))
      |> DateTime.to_unix()

    [
      day:
        {{pk, day_start * @seconds_per_day * 1000},
         {pk, (day_start + 1) * @seconds_per_day * 1000 - 1}},
      week:
        {{pk, week_start * 7 * @seconds_per_day * 1000},
         {pk, (week_start + 1) * 7 * @seconds_per_day * 1000 - 1}},
      month: {{pk, month_start * 1000}, {pk, next_month_start * 1000 - 1}}
    ]
  end

  @spec increment_statistics(State.t(), Stats.statistic_tag(), time(), pos_integer()) :: State.t()
  def increment_statistics(state, key, time, increment) do
    time
    |> time_intervals()
    |> Enum.reduce(state, fn {interval_by, interval_start}, state ->
      index = {key, interval_by, interval_start}

      State.update(
        state,
        Model.Statistic,
        index,
        fn Model.statistic(count: count) = statistics ->
          Model.statistic(statistics, count: count + increment)
        end,
        Model.statistic(index: index, count: 0)
      )
    end)
  end

  @spec increment_height_statistics(
          State.t(),
          Stats.statistic_tag(),
          Blocks.height(),
          pos_integer()
        ) :: State.t()
  def increment_height_statistics(state, key, height, increment) do
    index = {key, :height, height}

    State.update(
      state,
      Model.Statistic,
      index,
      fn Model.statistic(count: count) = statistics ->
        Model.statistic(statistics, count: count + increment)
      end,
      Model.statistic(index: index, count: 0)
    )
  end

  defp increment_collection_nfts(state, contract_pk, nil),
    do: update_stat_counter(state, Stats.nfts_count_key(contract_pk))

  defp increment_collection_nfts(state, _contract_pk, _prev_owner_pk), do: state

  defp decrement_collection_owners(state, _contract_pk, nil), do: state

  defp decrement_collection_owners(state, contract_pk, prev_owner_pk) do
    case State.next(
           state,
           Model.NftOwnerToken,
           {contract_pk, prev_owner_pk, Util.min_256bit_int()}
         ) do
      {:ok, {^contract_pk, ^prev_owner_pk, _token}} ->
        state

      _new_owner ->
        update_stat_counter(state, Stats.nft_owners_count_key(contract_pk), fn count ->
          max(count - 1, 0)
        end)
    end
  end

  defp increment_collection_owners(state, _contract_pk, nil), do: state

  defp increment_collection_owners(state, contract_pk, to_pk) do
    case State.next(state, Model.NftOwnerToken, {contract_pk, to_pk, Util.min_256bit_int()}) do
      {:ok, {^contract_pk, ^to_pk, _token}} -> state
      _new_owner -> update_stat_counter(state, Stats.nft_owners_count_key(contract_pk))
    end
  end

  defp update_stat_counter(state, key, update_fn \\ &(&1 + 1)) do
    State.update(
      state,
      Model.Stat,
      key,
      fn Model.stat(payload: count) = stat -> Model.stat(stat, payload: update_fn.(count)) end,
      Model.stat(index: key, payload: 0)
    )
  end
end
