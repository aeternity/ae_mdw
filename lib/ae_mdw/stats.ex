defmodule AeMdw.Stats do
  @moduledoc """
  Context module for dealing with Stats.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Database
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Node
  alias AeMdw.Util
  alias AeMdw.Validate
  alias AeMdw.Sync.Hyperchain

  require Model

  @type stat() :: map()
  @type delta_stat() :: map()
  @type total_stat() :: map()
  @type cursor() :: binary() | nil
  @type tps() :: non_neg_integer()
  @type statistic() :: map()

  @typep pubkey() :: Db.pubkey()
  @typep height() :: Blocks.height()
  @typep direction() :: Database.direction()
  @typep limit() :: Database.limit()
  @typep range() :: {:gen, Range.t()} | nil
  @typep aexn_type() :: :aex9 | :aex141
  @typep query() :: map()
  @typep pagination() :: Collection.direction_limit()
  @typep pagination_cursor() :: Collection.pagination_cursor()
  @typep reason() :: Error.t()
  @type miner :: map()

  @type nft_stats :: %{nfts_amount: non_neg_integer(), nft_owners: non_neg_integer()}
  @typep template_id() :: AeMdw.Aex141.template_id()

  @type blocks_tag() :: {:blocks, :key | :micro | :all}
  @type statistic_tag() ::
          {:transactions, Node.tx_type() | :all}
          | {:total_transactions, Node.tx_type() | :all}
          | :names_activated
          | :aex9_transfers
          | blocks_tag()
          | :difficulty
          | :hashrate
          | :contracts
          | :total_accounts
  @type interval_by() :: :day | :week | :month
  @type interval_start() :: non_neg_integer()

  @tps_stat_key :max_tps
  @miners_count_stat_key :miners_count
  @nfts_count_stat :nfts_count
  @nft_owners_count_stat :nft_owners_count
  @nft_template_tokens_stat :nft_template_tokens_count
  @aex9_count_stat :aex9_count
  @aex9_holder_count_stat :aex9_holder_count
  @aex9_logs_count_stat :aex9_logs_count
  @aex141_count_stat :aex141_count
  @holders_count_stat_key :holders_count

  @seconds_per_day 24 * 3_600
  @days_per_week 7

  @start_unix 1_970

  @interval_by_mapping %{
    "day" => :day,
    "week" => :week,
    "month" => :month
  }

  @spec max_tps_key() :: atom()
  def max_tps_key, do: @tps_stat_key

  @spec miners_count_key() :: atom()
  def miners_count_key, do: @miners_count_stat_key

  @spec nfts_count_key(pubkey()) :: {atom(), pubkey()}
  def nfts_count_key(contract_pk), do: {@nfts_count_stat, contract_pk}

  @spec aexn_count_key(aexn_type()) :: atom()
  def aexn_count_key(:aex9), do: @aex9_count_stat
  def aexn_count_key(:aex141), do: @aex141_count_stat

  @spec aex9_holder_count_key(pubkey()) :: {atom(), pubkey()}
  def aex9_holder_count_key(pubkey), do: {@aex9_holder_count_stat, pubkey}

  @spec aex9_logs_count_key(pubkey()) :: {atom(), pubkey()}
  def aex9_logs_count_key(pubkey), do: {@aex9_logs_count_stat, pubkey}

  @spec nft_template_tokens_key(pubkey(), template_id()) :: {atom(), pubkey(), template_id()}
  def nft_template_tokens_key(contract_pk, template_id),
    do: {@nft_template_tokens_stat, contract_pk, template_id}

  @spec nft_owners_count_key(pubkey()) :: {atom(), pubkey()}
  def nft_owners_count_key(contract_pk), do: {@nft_owners_count_stat, contract_pk}

  @spec holders_count_key() :: atom()
  def holders_count_key, do: @holders_count_stat_key

  @spec fetch_delta_stats(State.t(), direction(), range(), cursor(), limit()) ::
          {cursor(), [delta_stat()], cursor()}
  def fetch_delta_stats(state, direction, range, cursor, limit) do
    cursor = deserialize_cursor(cursor)

    with {:ok, last_gen} <- State.prev(state, Model.DeltaStat, nil),
         {:ok, scope} <- deserialize_scope(range, last_gen),
         {:ok, prev_cursor, range, next_cursor} <-
           Util.build_gen_pagination(cursor, direction, scope, limit, last_gen) do
      {serialize_cursor(prev_cursor), render_delta_stats(state, range),
       serialize_cursor(next_cursor)}
    else
      _error_or_none ->
        {nil, [], nil}
    end
  end

  @spec fetch_total_stats(State.t(), direction(), range(), cursor(), limit()) ::
          {cursor(), [total_stat()], cursor()}
  def fetch_total_stats(state, direction, range, cursor, limit) do
    cursor = deserialize_cursor(cursor)

    with {:ok, last_gen} <- State.prev(state, Model.DeltaStat, nil),
         {:ok, scope} <- deserialize_scope(range, last_gen),
         {:ok, prev_cursor, range, next_cursor} <-
           Util.build_gen_pagination(cursor, direction, scope, limit, last_gen) do
      {serialize_cursor(prev_cursor), render_total_stats(state, range),
       serialize_cursor(next_cursor)}
    else
      _error_or_none ->
        {nil, [], nil}
    end
  end

  @spec fetch_stats(State.t()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_stats(state) do
    with {:ok, Model.stat(payload: {tps, tps_block_hash})} <-
           State.get(state, Model.Stat, @tps_stat_key),
         {:ok, milliseconds_per_block} <- milliseconds_per_block(state),
         {:ok, Model.stat(index: @holders_count_stat_key, payload: holders_count)} <-
           State.get(state, Model.Stat, @holders_count_stat_key) do
      {{last_24hs_txs_count, trend}, {last_24hs_tx_fees_average, fees_trend}} =
        last_24hs_txs_count_and_fee_with_trend(state)

      stats =
        %{
          max_transactions_per_second: tps,
          max_transactions_per_second_block_hash: Enc.encode(:key_block_hash, tps_block_hash),
          last_24hs_transactions: last_24hs_txs_count,
          transactions_trend: trend,
          last_24hs_average_transaction_fees: last_24hs_tx_fees_average,
          fees_trend: fees_trend,
          milliseconds_per_block: milliseconds_per_block,
          holders_count: holders_count
        }

      stats =
        if Hyperchain.hyperchain?() do
          validators_count =
            state |> State.height() |> Hyperchain.validators_at_height() |> length()

          Map.put(stats, :validators_count, validators_count)
        else
          Model.stat(payload: miners_count) =
            State.fetch!(state, Model.Stat, @miners_count_stat_key)

          Map.put(stats, :miners_count, miners_count)
        end

      {:ok, stats}
    else
      _no_stats ->
        {:error, ErrInput.NotFound.exception(value: "no stats")}
    end
  end

  @spec fetch_delta_stat!(State.t(), height()) :: delta_stat()
  def fetch_delta_stat!(state, height),
    do: render_delta_stat(state, State.fetch!(state, Model.DeltaStat, height))

  @spec fetch_total_stat!(State.t(), height()) :: total_stat()
  def fetch_total_stat!(state, height),
    do: render_total_stat(state, State.fetch!(state, Model.TotalStat, height))

  @spec fetch_nft_stats(State.t(), pubkey()) :: nft_stats()
  def fetch_nft_stats(state, contract_pk) do
    with {:ok, Model.stat(payload: nfts_count)} <-
           State.get(state, Model.Stat, {@nfts_count_stat, contract_pk}),
         {:ok, Model.stat(payload: nft_owners)} <-
           State.get(state, Model.Stat, {@nft_owners_count_stat, contract_pk}) do
      %{
        nfts_amount: nfts_count,
        nft_owners: nft_owners
      }
    else
      :not_found ->
        %{
          nfts_amount: 0,
          nft_owners: 0
        }
    end
  end

  @spec fetch_aex9_holders_count(State.t(), pubkey()) :: integer()
  def fetch_aex9_holders_count(state, contract_pk) do
    case State.get(state, Model.Stat, aex9_holder_count_key(contract_pk)) do
      {:ok, Model.stat(payload: count)} -> count
      :not_found -> 0
    end
  end

  @spec fetch_aex9_logs_count(State.t(), pubkey()) :: integer()
  def fetch_aex9_logs_count(state, contract_pk) do
    case State.get(state, Model.Stat, aex9_logs_count_key(contract_pk)) do
      {:ok, Model.stat(payload: count)} -> count
      :not_found -> 0
    end
  end

  @spec fetch_transactions_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}}
  def fetch_transactions_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_transactions_param/1) do
      tx_tag = Map.get(filters, :tx_type, :all)

      fetch_statistics(state, pagination, filters, range, cursor, {:transactions, tx_tag})
    end
  end

  @spec fetch_transactions_total_stats(State.t(), query(), range()) ::
          {:ok, non_neg_integer()}
  def fetch_transactions_total_stats(state, query, range) do
    with {:ok, filters} <- Util.convert_params(query, &convert_transactions_param/1) do
      tx_tag = Map.get(filters, :tx_type, :all)
      tag = {:total_transactions, tx_tag}

      interval_by = :day
      filters = Map.put(filters, :interval_by, interval_by)

      {first_index, last_index} =
        generate_key_boundary(state, tag, filters, range)

      first_statistic_count =
        state
        |> State.prev(Model.Statistic, first_index)
        |> case do
          {:ok, {^tag, ^interval_by, _interval_start} = index} ->
            Model.statistic(count: count) = State.fetch!(state, Model.Statistic, index)
            count

          _otherwise ->
            0
        end

      last_statistic_count =
        state
        |> State.get(Model.Statistic, last_index)
        |> case do
          {:ok, Model.statistic(count: count)} ->
            count

          :not_found ->
            state
            |> State.prev(Model.Statistic, last_index)
            |> case do
              {:ok, {^tag, ^interval_by, _interval_start} = index} ->
                Model.statistic(count: count) = State.fetch!(state, Model.Statistic, index)
                count

              _otherwise ->
                0
            end
        end

      {:ok, abs(last_statistic_count - first_statistic_count)}
    end
  end

  @spec fetch_blocks_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_blocks_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_blocks_param/1) do
      type_tag = Map.get(filters, :block_type, :all)

      fetch_statistics(state, pagination, filters, range, cursor, {:blocks, type_tag})
    end
  end

  @spec fetch_difficulty_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_difficulty_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_blocks_param/1) do
      average_per_block(state, :difficulty, pagination, filters, range, cursor)
    end
  end

  @spec fetch_hashrate_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_hashrate_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_blocks_param/1) do
      average_per_block(state, :hashrate, pagination, filters, range, cursor)
    end
  end

  defp average_per_block(state, tag, pagination, filters, range, cursor) do
    with {:ok, {prev, counts, next}} <-
           fetch_statistics(state, pagination, filters, range, cursor, {:blocks, :key}),
         {:ok, {^prev, stats, ^next}} <-
           fetch_statistics(state, pagination, filters, range, cursor, tag) do
      [stats, counts]
      |> Enum.zip()
      |> Enum.map(fn {%{count: stat, start_date: start_date, end_date: end_date},
                      %{count: count, start_date: start_date, end_date: end_date}} ->
        average = if count == 0, do: 0, else: round(stat / count)
        %{start_date: start_date, end_date: end_date, count: average}
      end)
      |> then(&{:ok, {prev, &1, next}})
    end
  end

  @spec fetch_aex9_token_transfers_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_aex9_token_transfers_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      fetch_statistics(state, pagination, filters, range, cursor, :aex9_transfers)
    end
  end

  @spec fetch_names_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_names_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      fetch_statistics(state, pagination, filters, range, cursor, :names_activated)
    end
  end

  @spec fetch_contracts_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_contracts_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      fetch_statistics(state, pagination, filters, range, cursor, :contracts)
    end
  end

  @spec fetch_total_accounts_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_total_accounts_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      fetch_statistics(state, pagination, filters, range, cursor, :total_accounts)
    end
  end

  @spec fetch_active_accounts_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_active_accounts_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      fetch_statistics(state, pagination, filters, range, cursor, :active_accounts)
    end
  end

  @spec fetch_top_miners_stats(State.t(), pagination(), query(), range(), cursor()) ::
          {:ok, {pagination_cursor(), [statistic()], pagination_cursor()}} | {:error, reason()}
  def fetch_top_miners_stats(state, pagination, query, range, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1),
         {:ok, cursor} <- deserialize_top_miners_cursor(cursor) do
      paginated_top_miners =
        state
        |> build_top_miners_streamer(filters, range, cursor)
        |> Collection.paginate(
          pagination,
          &render_top_miner_statistic(state, &1),
          &serialize_top_miners_cursor/1
        )

      {:ok, paginated_top_miners}
    end
  end

  defp fetch_statistics(state, pagination, filters, range, cursor, tag) do
    with {:ok, cursor} <- deserialize_statistic_cursor(cursor) do
      paginated_statistics =
        state
        |> build_statistics_streamer(tag, filters, range, cursor)
        |> Collection.paginate(
          pagination,
          &render_statistic(state, &1),
          &serialize_statistics_cursor/1
        )

      {:ok, paginated_statistics}
    end
  end

  defp build_statistics_streamer(
         state,
         tag,
         filters,
         range,
         cursor
       ) do
    key_boundary =
      {{^tag, interval_by, min_date}, {^tag, interval_by, max_date}} =
      generate_key_boundary(state, tag, filters, range)

    cursor =
      case cursor do
        nil -> nil
        interval_start -> {tag, interval_by, interval_start}
      end

    fn direction ->
      state
      |> Collection.stream(Model.Statistic, direction, key_boundary, cursor)
      |> fill_missing_dates(tag, interval_by, direction, cursor, min_date, max_date)
    end
  end

  defp generate_key_boundary(state, tag, filters, scope) do
    interval_by = Map.get(filters, :interval_by, :day)
    {start_network_date, end_network_date} = DbUtil.network_date_interval(state)
    min_date = filters |> Map.get(:min_start_date, start_network_date) |> to_interval(interval_by)
    max_date = filters |> Map.get(:max_start_date, end_network_date) |> to_interval(interval_by)

    {min_date, max_date} =
      if scope do
        {first_txi, last_txi} = scope_to_txi(state, scope)

        min_date =
          state
          |> DbUtil.txi_to_time(first_txi)
          |> time_to_date()
          |> to_interval(interval_by)
          |> max(min_date)

        max_date =
          state
          |> DbUtil.txi_to_time(last_txi)
          |> time_to_date()
          |> to_interval(interval_by)
          |> min(max_date)

        {min_date, max_date}
      else
        {min_date, max_date}
      end

    {{tag, interval_by, min_date}, {tag, interval_by, max_date}}
  end

  defp build_top_miners_streamer(state, filters, _scope, cursor) do
    interval_by = Map.get(filters, :interval_by, :day)
    {start_network_date, end_network_date} = DbUtil.network_date_interval(state)
    min_date = filters |> Map.get(:min_start_date, start_network_date) |> to_interval(interval_by)
    max_date = filters |> Map.get(:max_start_date, end_network_date) |> to_interval(interval_by)

    key_boundary =
      {{interval_by, min_date, 0, Util.min_bin()},
       {interval_by, max_date, Util.max_int(), Util.max_256bit_bin()}}

    fn direction ->
      Collection.stream(state, Model.TopMinerStats, direction, key_boundary, cursor)
    end
  end

  defp fill_missing_dates(stream, tag, interval_by, :backward, cursor, min_date, max_date) do
    max_date =
      case cursor do
        nil -> max_date
        {_tag, _interval_by, interval_start} -> min(max_date, interval_start)
      end

    stream
    |> Stream.concat([:end])
    |> Stream.transform(max_date, fn
      :end, acc ->
        virtual_stream = Stream.map(acc..min_date//-1, &{:virtual, {tag, interval_by, &1}, 0})

        {virtual_stream, acc}

      {_tag, _interval_by, interval_start} = interval_key, interval_start ->
        {[{:db, interval_key}], interval_start - 1}

      {_tag, _interval_by, interval_start} = interval_key, acc ->
        virtual_stream =
          acc..(interval_start + 1)
          |> Stream.map(&{:virtual, {tag, interval_by, &1}, 0})
          |> Stream.concat([{:db, interval_key}])

        {virtual_stream, interval_start - 1}
    end)
  end

  defp fill_missing_dates(stream, tag, interval_by, :forward, cursor, min_date, max_date) do
    min_date =
      case cursor do
        nil -> min_date
        {_tag, _interval_by, interval_start} -> max(min_date, interval_start)
      end

    stream
    |> Stream.concat([:end])
    |> Stream.transform(min_date, fn
      :end, acc ->
        virtual_stream = Stream.map(acc..max_date//1, &{:virtual, {tag, interval_by, &1}, 0})

        {virtual_stream, acc}

      {_tag, _interval_by, interval_start} = interval_key, interval_start ->
        {[{:db, interval_key}], interval_start + 1}

      {_tag, _interval_by, interval_start} = interval_key, acc ->
        virtual_stream =
          acc..(interval_start - 1)
          |> Stream.map(&{:virtual, {tag, interval_by, &1}, 0})
          |> Stream.concat([{:db, interval_key}])

        {virtual_stream, interval_start + 1}
    end)
  end

  defp render_statistic(_state, {:virtual, {_tag, :month, interval_start}, count}) do
    %{
      start_date: months_to_iso(interval_start),
      end_date: months_to_iso(interval_start + 1),
      count: count
    }
  end

  defp render_statistic(_state, {:virtual, {_tag, :week, interval_start}, count}) do
    %{
      start_date: days_to_iso(interval_start * @days_per_week),
      end_date: days_to_iso((interval_start + 1) * @days_per_week),
      count: count
    }
  end

  defp render_statistic(_state, {:virtual, {_tag, :day, interval_start}, count}) do
    %{
      start_date: days_to_iso(interval_start),
      end_date: days_to_iso(interval_start + 1),
      count: count
    }
  end

  defp render_statistic(state, {:db, statistic_key}) do
    Model.statistic(count: count) = State.fetch!(state, Model.Statistic, statistic_key)

    render_statistic(state, {:virtual, statistic_key, count})
  end

  defp render_top_miner_statistic(
         _state,
         {:month, interval_start, count, beneficiary_id}
       ) do
    %{
      start_date: months_to_iso(interval_start),
      end_date: months_to_iso(interval_start + 1),
      miner: :aeapi.format_account_pubkey(beneficiary_id),
      blocks_mined: count
    }
  end

  defp render_top_miner_statistic(
         _state,
         {:week, interval_start, count, beneficiary_id}
       ) do
    %{
      start_date: days_to_iso(interval_start * @days_per_week),
      end_date: days_to_iso((interval_start + 1) * @days_per_week),
      miner: :aeapi.format_account_pubkey(beneficiary_id),
      blocks_mined: count
    }
  end

  defp render_top_miner_statistic(
         _state,
         {:day, interval_start, count, beneficiary_id}
       ) do
    %{
      start_date: days_to_iso(interval_start),
      end_date: days_to_iso(interval_start + 1),
      miner: :aeapi.format_account_pubkey(beneficiary_id),
      blocks_mined: count
    }
  end

  defp convert_blocks_param({"type", "key"}), do: {:ok, {:block_type, :key}}
  defp convert_blocks_param({"type", "micro"}), do: {:ok, {:block_type, :micro}}
  defp convert_blocks_param(param), do: convert_param(param)

  defp convert_transactions_param({"tx_type", val}) do
    case Validate.tx_type(val) do
      {:ok, tx_type} -> {:ok, {:tx_type, tx_type}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_transactions_param(param), do: convert_param(param)

  defp convert_param({"interval_by", val}) do
    case Map.fetch(@interval_by_mapping, val) do
      {:ok, interval_by} -> {:ok, {:interval_by, interval_by}}
      :error -> {:error, ErrInput.Query.exception(value: val)}
    end
  end

  defp convert_param({"min_start_date", val}), do: convert_date(:min_start_date, val)

  defp convert_param({"max_start_date", val}), do: convert_date(:max_start_date, val)

  defp convert_param({key, val}), do: {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}

  defp convert_date(key, val) do
    case Date.from_iso8601(val) do
      {:ok, date} -> {:ok, {key, date}}
      {:error, _reason} -> {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}
    end
  end

  defp serialize_statistics_cursor({:db, {_tag, _interval_by, interval_start}}),
    do: "#{interval_start}"

  defp serialize_statistics_cursor({:virtual, {_tag, _interval_by, interval_start}, _count}),
    do: "#{interval_start}"

  defp serialize_top_miners_cursor({_interval_by, _interval_start, _count, _ben} = cursor) do
    cursor
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp deserialize_statistic_cursor(nil), do: {:ok, nil}

  defp deserialize_statistic_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {interval_start, ""} -> {:ok, interval_start}
      _error_or_invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp deserialize_top_miners_cursor(nil), do: {:ok, nil}

  defp deserialize_top_miners_cursor(cursor_bin) do
    case Base.decode64(cursor_bin) do
      {:ok, bin} ->
        case :erlang.binary_to_term(bin) do
          cursor when is_tuple(cursor) -> {:ok, cursor}
          _bad_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
        end

      :error ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp render_delta_stats(state, gens), do: Enum.map(gens, &fetch_delta_stat!(state, &1))

  defp render_total_stats(state, gens), do: Enum.map(gens, &fetch_total_stat!(state, &1))

  defp render_delta_stat(
         state,
         Model.delta_stat(
           index: height,
           auctions_started: auctions_started,
           names_activated: names_activated,
           names_expired: names_expired,
           names_revoked: names_revoked,
           oracles_registered: oracles_registered,
           oracles_expired: oracles_expired,
           contracts_created: contracts_created,
           block_reward: block_reward,
           dev_reward: dev_reward,
           locked_in_auctions: locked_in_auctions,
           burned_in_auctions: burned_in_auctions,
           channels_opened: channels_opened,
           channels_closed: channels_closed,
           locked_in_channels: locked_in_channels
         )
       ) do
    %{
      height: height,
      auctions_started: auctions_started,
      names_activated: names_activated,
      names_expired: names_expired,
      names_revoked: names_revoked,
      oracles_registered: oracles_registered,
      oracles_expired: oracles_expired,
      contracts_created: contracts_created,
      block_reward: block_reward,
      dev_reward: dev_reward,
      locked_in_auctions: locked_in_auctions,
      burned_in_auctions: burned_in_auctions,
      channels_opened: channels_opened,
      channels_closed: channels_closed,
      locked_in_channels: locked_in_channels,
      last_tx_hash: fetch_last_tx_hash!(state, height)
    }
  end

  defp render_total_stat(
         state,
         Model.total_stat(
           index: height,
           active_auctions: active_auctions,
           active_names: active_names,
           active_oracles: active_oracles,
           contracts: contracts,
           inactive_names: inactive_names,
           inactive_oracles: inactive_oracles,
           block_reward: block_reward,
           dev_reward: dev_reward,
           total_supply: total_supply,
           locked_in_auctions: locked_in_auctions,
           burned_in_auctions: burned_in_auctions,
           open_channels: open_channels,
           locked_in_channels: locked_in_channels
         )
       ) do
    %{
      height: height,
      active_auctions: active_auctions,
      active_names: active_names,
      active_oracles: active_oracles,
      contracts: contracts,
      inactive_names: inactive_names,
      inactive_oracles: inactive_oracles,
      sum_block_reward: block_reward,
      sum_dev_reward: dev_reward,
      total_token_supply: total_supply,
      locked_in_auctions: locked_in_auctions,
      burned_in_auctions: burned_in_auctions,
      open_channels: open_channels,
      locked_in_channels: locked_in_channels,
      last_tx_hash: fetch_last_tx_hash!(state, height)
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(gen), do: {Integer.to_string(gen), false}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end

  defp deserialize_scope(nil, last_gen), do: {:ok, {1, last_gen}}
  defp deserialize_scope({:gen, first..last//_step}, _last_gen), do: {:ok, {max(first, 1), last}}

  defp deserialize_scope({:txi, _range}, _last_gen),
    do: {:error, ErrInput.Scope.exception(value: "can't use txi scope on gen-based resource")}

  defp fetch_last_tx_hash!(state, height) do
    case State.get(state, Model.Block, {height + 1, -1}) do
      {:ok, Model.block(tx_index: 0)} ->
        nil

      {:ok, Model.block(tx_index: tx_index)} ->
        Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, tx_index - 1)

        Enc.encode(:tx_hash, tx_hash)

      :not_found ->
        case DbUtil.last_txi(state) do
          {:ok, txi} ->
            Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
            Enc.encode(:tx_hash, tx_hash)

          :none ->
            nil
        end
    end
  end

  defp last_24hs_txs_count_and_fee_with_trend(state) do
    state
    |> State.get(Model.Stat, :tx_stats)
    |> case do
      {:ok,
       Model.stat(
         payload:
           {_started_at, {{txs_count_24hs, trend_str}, {average_tx_fees_24hs_str, fee_trend_str}}}
       )} ->
        trend = String.to_float(trend_str)
        fees_trend = String.to_float(fee_trend_str)
        average_tx_fees_24hs = String.to_float(average_tx_fees_24hs_str)

        {{txs_count_24hs, trend}, {average_tx_fees_24hs, fees_trend}}

      :not_found ->
        {{0, 0.0}, {0.0, 0.0}}
    end
  end

  defp months_to_iso(months) do
    year = div(months, 12)
    month = rem(months, 12) + 1

    (@start_unix + year)
    |> Date.new!(month, 1)
    |> Date.to_iso8601()
  end

  defp days_to_iso(days) do
    (days * @seconds_per_day)
    |> DateTime.from_unix!()
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end

  defp time_to_date(time) do
    time
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_date()
  end

  defp to_interval(date, interval_by) do
    seconds = date |> DateTime.new!(Time.new!(0, 0, 0)) |> DateTime.to_unix()
    day_start = div(seconds, @seconds_per_day)

    case interval_by do
      :day ->
        day_start

      :week ->
        div(day_start, 7)

      :month ->
        %DateTime{year: year, month: month} = DateTime.from_unix!(seconds)
        (year - @start_unix) * 12 + month - 1
    end
  end

  @spec milliseconds_per_block(State.t()) :: {:ok, non_neg_integer() | nil} | {:error, reason()}
  defp milliseconds_per_block(state) do
    with {:ok, first_block} <- :aec_chain.get_key_block_by_height(1),
         {:ok, last_gen} <- DbUtil.last_gen(state),
         {:ok, last_block} <- get_last_key_block(last_gen) do
      first_block_time = :aec_blocks.time_in_msecs(first_block)

      last_block_time =
        :aec_blocks.time_in_msecs(last_block)

      {:ok, div(last_block_time - first_block_time, last_gen)}
    else
      {:error, :chain_too_short} -> {:ok, nil}
      error -> error
    end
  end

  @spec fetch_top_miners_24hs(State.t()) :: [miner()]
  def fetch_top_miners_24hs(state) do
    now = :aeu_time.now_in_msecs()
    time_24h_ago = now - @seconds_per_day * 1_000
    kb = {time_24h_ago, now}

    state
    |> Collection.stream(Model.KeyBlockTime, :backward, kb, nil)
    |> Enum.reduce(%{}, fn index, acc ->
      Model.key_block_time(miner: miner) = State.fetch!(state, Model.KeyBlockTime, index)
      Map.update(acc, miner, 1, &(&1 + 1))
    end)
    |> Enum.map(&render_miner/1)
  end

  defp get_last_key_block(gen) do
    case :aec_chain.get_key_block_by_height(gen) do
      {:ok, block} -> {:ok, block}
      {:error, :chain_too_short} -> :aec_chain.get_key_block_by_height(gen - 1)
    end
  end

  defp render_miner({miner, count}) do
    %{miner: :aeapi.format_account_pubkey(miner), blocks_mined: count}
  end

  defp scope_to_txi(state, {:gen, first_gen..last_gen//_step}) do
    {DbUtil.first_gen_to_txi(state, first_gen), DbUtil.last_gen_to_txi(state, last_gen)}
  end

  defp scope_to_txi(_state, {:txi, first_txi..last_txi//_step}) do
    {first_txi, last_txi}
  end
end
