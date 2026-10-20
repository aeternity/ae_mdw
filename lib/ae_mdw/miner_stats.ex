defmodule AeMdw.MinerStats do
  @moduledoc """
  Mining stats per miner, by its key or by its beneficiary, and for the whole network,
  bucketed by consecutive generations (see `AeMdw.MinerStats.Fold`).
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.EtsCache
  alias AeMdw.MinerStats.Fold
  alias AeMdw.MinerStats.Folder
  alias AeMdw.Node
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type role() :: Model.miner_role()
  @type scope() :: {:gen, Range.t()} | nil
  @type cursor() :: binary() | nil
  @type query() :: %{binary() => binary() | integer()}
  @typep state() :: State.t()
  @typep pagination() :: Collection.direction_limit()
  @typep order_by() :: :blocks | :txs | :rewards | :fees | :first_active | :last_active

  @roles %{"miner" => :miner, "beneficiary" => :beneficiary}
  # a bucket is about an hour of generations
  @intervals_by %{"day" => 24, "week" => 24 * 7, "month" => 24 * 30}
  @max_interval 24 * 30
  @max_buckets_per_page 20_000

  @cache_table :miner_stats_sorted
  @cache_expiration_minutes 10

  @spec init_cache() :: :ok
  def init_cache, do: EtsCache.new(@cache_table, @cache_expiration_minutes)

  @doc """
  Totals of the whole chain and how far the stats have been folded, since they're built
  in the background from the finalized generations.
  """
  @spec fetch_summary(state()) :: {:ok, map()}
  def fetch_summary(state) do
    summary = %{
      bucket_size: Fold.bucket_size(),
      synced_height: Folder.folded_height(state),
      last_bucket: nil,
      blocks: 0,
      txs: 0,
      rewards: 0,
      fees: 0,
      miners: 0,
      beneficiaries: 0
    }

    case State.prev(state, Model.NetworkBucket, nil) do
      {:ok, bucket} ->
        Model.network_bucket(
          blocks_total: blocks,
          txs_total: txs,
          rewards_total: rewards,
          fees_total: fees,
          miners_total: miners,
          beneficiaries_total: beneficiaries
        ) = State.fetch!(state, Model.NetworkBucket, bucket)

        {:ok,
         %{
           summary
           | last_bucket: bucket,
             blocks: blocks,
             txs: txs,
             rewards: rewards,
             fees: fees,
             miners: miners,
             beneficiaries: beneficiaries
         }}

      :none ->
        {:ok, summary}
    end
  end

  @doc """
  Miners (or beneficiaries) sorted by one of their totals or by when they first or last
  mined.
  """
  @spec fetch_miners(state(), pagination(), query(), order_by() | nil, cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_miners(state, pagination, query, order_by, cursor) do
    with {:ok, role, rest} <- split_role(query),
         :ok <- check_params(rest, []),
         {:ok, cursor} <- deserialize_miner_cursor(cursor) do
      sorted = sorted_miners(state, role, order_by || :blocks)

      stream_fn = fn
        :forward -> drop_before(sorted, cursor)
        :backward -> sorted |> Enum.reverse() |> drop_after(cursor)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {_value, pk} -> render_miner(State.fetch!(state, Model.MinerEntity, {role, pk})) end,
        &serialize_miner_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_miner(state(), query(), binary()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_miner(state, query, id) do
    with {:ok, role, rest} <- split_role(query),
         :ok <- check_params(rest, []),
         {:ok, pk} <- Validate.id(id, [:account_pubkey]),
         {:ok, entity} <- found(State.get(state, Model.MinerEntity, {role, pk}), id) do
      {:ok, render_miner(entity)}
    end
  end

  @doc """
  The beneficiaries that a miner key mined for or the miner keys that mined for a
  beneficiary.
  """
  @spec fetch_links(state(), pagination(), query(), binary(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_links(state, pagination, query, id, cursor) do
    with {:ok, role, rest} <- split_role(query),
         :ok <- check_params(rest, []),
         {:ok, pk} <- Validate.id(id, [:account_pubkey]),
         {:ok, cursor_pk} <- deserialize_pubkey_cursor(cursor) do
      table = if role == :miner, do: Model.MinerLink, else: Model.BeneficiaryLink
      boundary = {{pk, <<>>}, {pk, Util.max_256bit_bin()}}
      cursor_key = cursor_pk && {pk, cursor_pk}

      stream_fn = fn direction ->
        Collection.stream(state, table, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        &render_link(state, role, &1),
        fn {_pk, other_pk} -> encode(other_pk) end
      )
      |> then(&{:ok, &1})
    end
  end

  @doc """
  Series of a miner, one row per interval of buckets where it mined or got paid.
  """
  @spec fetch_miner_series(state(), pagination(), binary(), scope(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_miner_series(state, pagination, id, scope, query, cursor) do
    with {:ok, role, rest} <- split_role(query),
         {:ok, pk} <- Validate.id(id, [:account_pubkey]),
         {:ok, interval} <- convert_interval(rest) do
      ctx = %{
        table: Model.MinerBucket,
        key: &{role, pk, &1},
        bucket_of: fn {_role, _pk, bucket} -> bucket end
      }

      series(
        state,
        pagination,
        scope,
        interval,
        cursor,
        ctx,
        &render_miner_group(state, &1, role)
      )
    end
  end

  @spec fetch_network_series(state(), pagination(), scope(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_network_series(state, pagination, scope, query, cursor) do
    with {:ok, interval} <- convert_interval(query) do
      ctx = %{table: Model.NetworkBucket, key: & &1, bucket_of: & &1}

      series(state, pagination, scope, interval, cursor, ctx, &render_network_group(state, &1))
    end
  end

  @spec fetch_bucket(state(), Model.bucket()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_bucket(state, bucket) do
    with {:ok, row} <- found(State.get(state, Model.NetworkBucket, bucket), "#{bucket}") do
      {:ok, render_network_rows(state, bucket, 1, [row])}
    end
  end

  @doc """
  The miners (or beneficiaries) that mined in a bucket.
  """
  @spec fetch_bucket_miners(state(), pagination(), Model.bucket(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_bucket_miners(state, pagination, bucket, query, cursor) do
    with {:ok, role, rest} <- split_role(query),
         :ok <- check_params(rest, []),
         {:ok, cursor_pk} <- deserialize_pubkey_cursor(cursor) do
      boundary = {{role, bucket, <<>>}, {role, bucket, Util.max_256bit_bin()}}
      cursor_key = cursor_pk && {role, bucket, cursor_pk}

      stream_fn = fn direction ->
        Collection.stream(state, Model.BucketMiner, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {^role, ^bucket, pk} ->
          row = State.fetch!(state, Model.MinerBucket, {role, pk, bucket})

          state
          |> render_miner_group({bucket, 1, [row]}, role)
          |> Map.put(:id, encode(pk))
        end,
        fn {_role, _bucket, pk} -> encode(pk) end
      )
      |> then(&{:ok, &1})
    end
  end

  # Series

  defp series(
         state,
         {_dir, _rev?, limit, _cursor?} = pagination,
         scope,
         interval,
         cursor,
         ctx,
         render
       ) do
    with :ok <- check_buckets_per_page(limit, interval),
         {:ok, cursor_group} <- deserialize_group_cursor(cursor) do
      {first_bucket, last_bucket} = bucket_range(scope)

      stream_fn = fn direction ->
        cursor_bucket = cursor_group && group_cursor_bucket(cursor_group, interval, direction)
        boundary = {ctx.key.(first_bucket), ctx.key.(last_bucket)}

        state
        |> Collection.stream(
          ctx.table,
          direction,
          boundary,
          cursor_bucket && ctx.key.(cursor_bucket)
        )
        |> Stream.chunk_by(&div(ctx.bucket_of.(&1), interval))
        |> Stream.map(fn [key | _rest] = keys -> {div(ctx.bucket_of.(key), interval), keys} end)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {group, keys} ->
          render.({group * interval, interval, fetch_rows(state, ctx.table, keys)})
        end,
        fn {group, _keys} -> Integer.to_string(group) end
      )
      |> then(&{:ok, &1})
    end
  end

  defp fetch_rows(state, table, keys) do
    keys
    |> Enum.map(&State.fetch!(state, table, &1))
    |> Enum.sort_by(&row_bucket/1)
  end

  defp row_bucket(Model.network_bucket(index: bucket)), do: bucket
  defp row_bucket(Model.miner_bucket(index: {_role, _pk, bucket})), do: bucket

  defp check_buckets_per_page(limit, interval) when limit * interval <= @max_buckets_per_page,
    do: :ok

  defp check_buckets_per_page(limit, interval),
    do: {:error, ErrInput.Query.exception(value: "too many buckets `#{limit * interval}`")}

  defp bucket_range(nil), do: {0, Util.max_int()}

  defp bucket_range({:gen, first_gen..last_gen//_step}),
    do: {Fold.bucket(first_gen), Fold.bucket(last_gen)}

  # The cursor is the first group of the page, a group of buckets is walked from its
  # first one going forward and from its last one going backward.
  defp group_cursor_bucket(group, interval, :forward), do: group * interval
  defp group_cursor_bucket(group, interval, :backward), do: group * interval + interval - 1

  # Rendering

  defp render_miner(
         Model.miner_entity(
           index: {role, pk},
           first_height: first_height,
           first_time: first_time,
           last_height: last_height,
           last_time: last_time,
           blocks: blocks,
           txs: txs,
           rewards: rewards,
           fees: fees,
           last_info: last_info,
           info_changes: info_changes
         )
       ) do
    %{
      id: encode(pk),
      role: Atom.to_string(role),
      first_height: first_height,
      first_time: first_time,
      last_height: last_height,
      last_time: last_time,
      blocks: blocks,
      txs: txs,
      rewards: rewards_for(role, rewards),
      fees: fees,
      last_info: last_info,
      info_changes: info_changes
    }
  end

  # Only beneficiaries get rewards.
  defp rewards_for(:miner, _rewards), do: nil
  defp rewards_for(:beneficiary, rewards), do: rewards

  defp render_link(state, :miner, {miner_pk, beneficiary_pk}) do
    Model.miner_link(blocks: blocks, first_height: first_height, last_height: last_height) =
      State.fetch!(state, Model.MinerLink, {miner_pk, beneficiary_pk})

    %{
      id: encode(beneficiary_pk),
      role: "beneficiary",
      blocks: blocks,
      first_height: first_height,
      last_height: last_height
    }
  end

  defp render_link(state, :beneficiary, {beneficiary_pk, miner_pk}) do
    Model.miner_link(blocks: blocks, first_height: first_height, last_height: last_height) =
      State.fetch!(state, Model.MinerLink, {miner_pk, beneficiary_pk})

    %{
      id: encode(miner_pk),
      role: "miner",
      blocks: blocks,
      first_height: first_height,
      last_height: last_height
    }
  end

  defp render_miner_group(state, {first_bucket, interval, rows}, role) do
    Model.miner_bucket(
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total
    ) = List.last(rows)

    %{
      bucket: first_bucket,
      interval: interval,
      start_height: first_bucket * Fold.bucket_size(),
      end_height: (first_bucket + interval) * Fold.bucket_size() - 1,
      start_time: start_time(state, first_bucket, interval),
      end_time: end_time(state, first_bucket, interval),
      blocks: sum(rows, &Model.miner_bucket(&1, :blocks)),
      txs: sum(rows, &Model.miner_bucket(&1, :txs)),
      rewards: rewards_for(role, sum(rows, &Model.miner_bucket(&1, :rewards))),
      fees: sum(rows, &Model.miner_bucket(&1, :fees)),
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_for(role, rewards_total),
      fees_total: fees_total
    }
  end

  defp render_network_group(state, {first_bucket, interval, rows}),
    do: render_network_rows(state, first_bucket, interval, rows)

  defp render_network_rows(state, first_bucket, interval, rows) do
    first = List.first(rows)
    last = List.last(rows)
    blocks = sum(rows, &Model.network_bucket(&1, :blocks))
    difficulty_sum = sum(rows, &Model.network_bucket(&1, :difficulty_sum))
    start_time = Model.network_bucket(first, :start_time)
    end_time = Model.network_bucket(last, :end_time)

    Model.network_bucket(
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total,
      miners_total: miners_total,
      beneficiaries_total: beneficiaries_total
    ) = last

    %{
      bucket: first_bucket,
      interval: interval,
      start_height: Model.network_bucket(first, :start_height),
      end_height: Model.network_bucket(last, :end_height),
      start_time: start_time,
      end_time: end_time,
      blocks: blocks,
      micro_blocks: sum(rows, &Model.network_bucket(&1, :micro_blocks)),
      txs: sum(rows, &Model.network_bucket(&1, :txs)),
      rewards: sum(rows, &Model.network_bucket(&1, :rewards)),
      fees: sum(rows, &Model.network_bucket(&1, :fees)),
      avg_block_time: avg_block_time(start_time, end_time, blocks),
      avg_difficulty: if(blocks > 0, do: div(difficulty_sum, blocks)),
      hashrate: if(blocks > 0, do: Node.difficulty_to_hashrate(div(difficulty_sum, blocks))),
      active_miners: active(state, :miner, first_bucket, interval, rows),
      active_beneficiaries: active(state, :beneficiary, first_bucket, interval, rows),
      new_miners: sum(rows, &Model.network_bucket(&1, :new_miners)),
      new_beneficiaries: sum(rows, &Model.network_bucket(&1, :new_beneficiaries)),
      top_miner_blocks:
        rows |> Enum.map(&Model.network_bucket(&1, :top_miner_blocks)) |> Enum.max(),
      top_beneficiary_blocks:
        rows |> Enum.map(&Model.network_bucket(&1, :top_beneficiary_blocks)) |> Enum.max(),
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total,
      miners_total: miners_total,
      beneficiaries_total: beneficiaries_total
    }
  end

  defp avg_block_time(start_time, end_time, blocks) when blocks > 1,
    do: div(end_time - start_time, blocks - 1)

  defp avg_block_time(_start_time, _end_time, _blocks), do: nil

  # The ones active in several buckets are only counted once, which can't be told by
  # adding the buckets up.
  defp active(_state, role, _first_bucket, _interval, [row]) do
    case role do
      :miner -> Model.network_bucket(row, :active_miners)
      :beneficiary -> Model.network_bucket(row, :active_beneficiaries)
    end
  end

  defp active(state, role, first_bucket, interval, _rows) do
    boundary =
      {{role, first_bucket, <<>>}, {role, first_bucket + interval - 1, Util.max_256bit_bin()}}

    state
    |> Collection.stream(Model.BucketMiner, :forward, boundary, nil)
    |> Enum.uniq_by(fn {_role, _bucket, pk} -> pk end)
    |> length()
  end

  defp start_time(state, first_bucket, interval) do
    with {:ok, bucket} <- State.next(state, Model.NetworkBucket, first_bucket - 1),
         true <- bucket < first_bucket + interval do
      Model.network_bucket(start_time: time) = State.fetch!(state, Model.NetworkBucket, bucket)
      time
    else
      _no_bucket -> nil
    end
  end

  defp end_time(state, first_bucket, interval) do
    with {:ok, bucket} <- State.prev(state, Model.NetworkBucket, first_bucket + interval),
         true <- bucket >= first_bucket do
      Model.network_bucket(end_time: time) = State.fetch!(state, Model.NetworkBucket, bucket)
      time
    else
      _no_bucket -> nil
    end
  end

  defp sum(rows, fun), do: rows |> Enum.map(fun) |> Enum.sum()

  defp encode(pk), do: Enc.encode(:account_pubkey, pk)

  defp found({:ok, entity}, _id), do: {:ok, entity}
  defp found(:not_found, id), do: {:error, ErrInput.NotFound.exception(value: id)}

  # Sorted miners

  # Ascending [{value, pubkey}] of the role, cached while there's nothing new folded.
  defp sorted_miners(state, role, order_by) do
    cache_key = {role, order_by, Folder.folded_height(state)}

    case EtsCache.get(@cache_table, cache_key) do
      {sorted, _inserted_at} ->
        sorted

      nil ->
        sorted =
          state
          |> Collection.stream(
            Model.MinerEntity,
            :forward,
            {{role, <<>>}, {role, Util.max_256bit_bin()}},
            nil
          )
          |> Enum.map(fn {^role, pk} = key ->
            {order_value(State.fetch!(state, Model.MinerEntity, key), order_by), pk}
          end)
          |> Enum.sort()

        EtsCache.put(@cache_table, cache_key, sorted)
        sorted
    end
  end

  defp order_value(entity, :blocks), do: Model.miner_entity(entity, :blocks)
  defp order_value(entity, :txs), do: Model.miner_entity(entity, :txs)
  defp order_value(entity, :rewards), do: Model.miner_entity(entity, :rewards)
  defp order_value(entity, :fees), do: Model.miner_entity(entity, :fees)
  defp order_value(entity, :first_active), do: Model.miner_entity(entity, :first_height) || -1
  defp order_value(entity, :last_active), do: Model.miner_entity(entity, :last_height) || -1

  # The cursor is the first miner of the page, so it's kept (even if it moved since then).
  defp drop_before(sorted, nil), do: sorted
  defp drop_before(sorted, cursor), do: Enum.drop_while(sorted, &(&1 < cursor))

  defp drop_after(sorted, nil), do: sorted
  defp drop_after(sorted, cursor), do: Enum.drop_while(sorted, &(&1 > cursor))

  # Params and cursors

  defp split_role(query) do
    case Map.pop(query, "role") do
      {nil, rest} ->
        {:ok, :miner, rest}

      {role, rest} ->
        case Map.fetch(@roles, role) do
          {:ok, role} -> {:ok, role, rest}
          :error -> {:error, ErrInput.Query.exception(value: "role=#{role}")}
        end
    end
  end

  defp check_params(query, allowed_keys) do
    case Enum.find(query, fn {key, _val} -> key not in allowed_keys end) do
      nil -> :ok
      {key, val} -> {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}
    end
  end

  defp convert_interval(query) do
    with :ok <- check_params(query, ["interval", "interval_by"]) do
      case {Map.get(query, "interval"), Map.get(query, "interval_by")} do
        {nil, nil} ->
          {:ok, 1}

        {interval, nil} ->
          interval_param(interval)

        {nil, interval_by} ->
          interval_by_param(interval_by)

        {_interval, interval_by} ->
          {:error, ErrInput.Query.exception(value: "interval_by=#{interval_by}")}
      end
    end
  end

  defp interval_param(interval)
       when is_integer(interval) and interval > 0 and interval <= @max_interval,
       do: {:ok, interval}

  defp interval_param(interval) when is_binary(interval) do
    case Integer.parse(interval) do
      {interval, ""} -> interval_param(interval)
      _invalid -> {:error, ErrInput.Query.exception(value: "interval=#{interval}")}
    end
  end

  defp interval_param(interval),
    do: {:error, ErrInput.Query.exception(value: "interval=#{interval}")}

  defp interval_by_param(interval_by) do
    case Map.fetch(@intervals_by, interval_by) do
      {:ok, interval} -> {:ok, interval}
      :error -> {:error, ErrInput.Query.exception(value: "interval_by=#{interval_by}")}
    end
  end

  @spec parse_bucket(binary() | integer()) :: {:ok, Model.bucket()} | {:error, Error.t()}
  def parse_bucket(bucket) when is_integer(bucket) and bucket >= 0, do: {:ok, bucket}

  def parse_bucket(bucket) when is_binary(bucket) do
    case Integer.parse(bucket) do
      {bucket, ""} -> parse_bucket(bucket)
      _invalid -> {:error, ErrInput.Query.exception(value: "bucket=#{bucket}")}
    end
  end

  def parse_bucket(bucket), do: {:error, ErrInput.Query.exception(value: "bucket=#{bucket}")}

  defp serialize_miner_cursor({value, pk}) do
    {value, pk}
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end

  defp deserialize_miner_cursor(nil), do: {:ok, nil}

  defp deserialize_miner_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {value, <<pk::256>>} when is_integer(value) <-
           :erlang.binary_to_term(cursor_bin, [:safe]) do
      {:ok, {value, <<pk::256>>}}
    else
      _invalid_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_hex)}
  end

  defp deserialize_pubkey_cursor(nil), do: {:ok, nil}

  defp deserialize_pubkey_cursor(cursor) do
    case Enc.safe_decode(:account_pubkey, cursor) do
      {:ok, pk} -> {:ok, pk}
      {:error, _reason} -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp deserialize_group_cursor(nil), do: {:ok, nil}

  defp deserialize_group_cursor(cursor) do
    case Integer.parse(cursor) do
      {group, ""} when group >= 0 -> {:ok, group}
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end
end
