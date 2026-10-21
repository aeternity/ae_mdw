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
  alias AeMdw.Miners
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
  @intervals_by %{"day" => 24, "week" => 24 * 7, "month" => 24 * 30, "year" => 24 * 365}

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

    # the keys are sorted by interval, so the one before any other is the last bucket
    case State.prev(state, Model.NetworkBucket, {2, 0}) do
      {:ok, {1, bucket} = key} ->
        Model.network_bucket(
          blocks_total: blocks,
          txs_total: txs,
          rewards_total: rewards,
          fees_total: fees,
          miners_total: miners,
          beneficiaries_total: beneficiaries
        ) = State.fetch!(state, Model.NetworkBucket, key)

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
         :ok <- check_order(role, order_by),
         {:ok, cursor} <- Miners.deserialize_cursor(cursor) do
      sorted = sorted_miners(state, role, order_by || :blocks)

      stream_fn = fn
        :forward -> drop_before(sorted, cursor)
        :backward -> sorted |> Enum.reverse() |> drop_after(cursor)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {_value, pk} -> render_miner(State.fetch!(state, Model.MinerEntity, {role, pk})) end,
        &Miners.serialize_cursor/1
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
      series(
        state,
        pagination,
        scope,
        interval,
        cursor,
        Model.MinerBucket,
        &{role, pk, interval, &1},
        &render_miner_row(state, role, &1)
      )
    end
  end

  @spec fetch_network_series(state(), pagination(), scope(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_network_series(state, pagination, scope, query, cursor) do
    with {:ok, interval} <- convert_interval(query) do
      series(
        state,
        pagination,
        scope,
        interval,
        cursor,
        Model.NetworkBucket,
        &{interval, &1},
        &render_network_row(state, &1)
      )
    end
  end

  @spec fetch_bucket(state(), Model.bucket()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_bucket(state, bucket) do
    with {:ok, _row} <- found(State.get(state, Model.NetworkBucket, {1, bucket}), "#{bucket}") do
      {:ok, render_network_row(state, {1, bucket})}
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
      boundary = {{role, 1, bucket, <<>>}, {role, 1, bucket, Util.max_256bit_bin()}}
      cursor_key = cursor_pk && {role, 1, bucket, cursor_pk}

      stream_fn = fn direction ->
        Collection.stream(state, Model.BucketMiner, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {^role, 1, ^bucket, pk} ->
          state
          |> render_miner_row(role, {role, pk, 1, bucket})
          |> Map.put(:id, encode(pk))
        end,
        fn {_role, 1, _bucket, pk} -> encode(pk) end
      )
      |> then(&{:ok, &1})
    end
  end

  # Every interval is indexed, with the group in the last place of the key, which is also
  # what the cursor is.
  defp series(state, pagination, scope, interval, cursor, table, key_fun, render_fun) do
    with {:ok, cursor_group} <- deserialize_group_cursor(cursor) do
      {first_group, last_group} = group_range(scope, interval)
      boundary = {key_fun.(first_group), key_fun.(last_group)}

      stream_fn = fn direction ->
        cursor_key = cursor_group && key_fun.(cursor_group)

        Collection.stream(state, table, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(pagination, render_fun, &serialize_group_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  defp group_range(nil, _interval), do: {0, Util.max_int()}

  defp group_range({:gen, first_gen..last_gen//_step}, interval),
    do: {div(Fold.bucket(first_gen), interval), div(Fold.bucket(last_gen), interval)}

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

  defp render_miner_row(state, role, {_role, _pk, interval, group} = key) do
    Model.miner_bucket(
      blocks: blocks,
      txs: txs,
      rewards: rewards,
      fees: fees,
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total
    ) = State.fetch!(state, Model.MinerBucket, key)

    network_row = State.fetch!(state, Model.NetworkBucket, {interval, group})

    %{
      bucket: group * interval,
      interval: interval,
      start_height: group * interval * Fold.bucket_size(),
      end_height: (group + 1) * interval * Fold.bucket_size() - 1,
      start_time: Model.network_bucket(network_row, :start_time),
      end_time: Model.network_bucket(network_row, :end_time),
      blocks: blocks,
      txs: txs,
      rewards: rewards_for(role, rewards),
      fees: fees,
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_for(role, rewards_total),
      fees_total: fees_total
    }
  end

  defp render_network_row(state, {interval, group} = key) do
    Model.network_bucket(
      start_height: start_height,
      end_height: end_height,
      start_time: start_time,
      end_time: end_time,
      blocks: blocks,
      micro_blocks: micro_blocks,
      txs: txs,
      rewards: rewards,
      fees: fees,
      difficulty_sum: difficulty_sum,
      active_miners: active_miners,
      active_beneficiaries: active_beneficiaries,
      new_miners: new_miners,
      new_beneficiaries: new_beneficiaries,
      top_miner_blocks: top_miner_blocks,
      top_beneficiary_blocks: top_beneficiary_blocks,
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total,
      miners_total: miners_total,
      beneficiaries_total: beneficiaries_total
    ) = State.fetch!(state, Model.NetworkBucket, key)

    %{
      bucket: group * interval,
      interval: interval,
      start_height: start_height,
      end_height: end_height,
      start_time: start_time,
      end_time: end_time,
      blocks: blocks,
      micro_blocks: micro_blocks,
      txs: txs,
      rewards: rewards,
      fees: fees,
      avg_block_time: avg_block_time(start_time, end_time, blocks),
      avg_difficulty: if(blocks > 0, do: div(difficulty_sum, blocks)),
      hashrate: if(blocks > 0, do: Node.difficulty_to_hashrate(div(difficulty_sum, blocks))),
      active_miners: active_miners,
      active_beneficiaries: active_beneficiaries,
      new_miners: new_miners,
      new_beneficiaries: new_beneficiaries,
      top_miner_blocks: top_miner_blocks,
      top_beneficiary_blocks: top_beneficiary_blocks,
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

  defp encode(pk), do: Enc.encode(:account_pubkey, pk)

  defp found({:ok, entity}, _id), do: {:ok, entity}
  defp found(:not_found, id), do: {:error, ErrInput.NotFound.exception(value: id)}

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

  # Only beneficiaries get rewards.
  defp check_order(:miner, :rewards), do: {:error, ErrInput.Query.exception(value: "by=rewards")}
  defp check_order(_role, _order_by), do: :ok

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

  defp interval_param(interval) when is_integer(interval) do
    if interval in Fold.intervals() do
      {:ok, interval}
    else
      {:error, ErrInput.Query.exception(value: "interval=#{interval}")}
    end
  end

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

  defp deserialize_pubkey_cursor(nil), do: {:ok, nil}

  defp deserialize_pubkey_cursor(cursor) do
    case Enc.safe_decode(:account_pubkey, cursor) do
      {:ok, pk} -> {:ok, pk}
      {:error, _reason} -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  # The group is the last element of the key of the series rows.
  defp serialize_group_cursor(key), do: key |> elem(tuple_size(key) - 1) |> Integer.to_string()

  defp deserialize_group_cursor(nil), do: {:ok, nil}

  defp deserialize_group_cursor(cursor) do
    case Integer.parse(cursor) do
      {group, ""} when group >= 0 -> {:ok, group}
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end
end
