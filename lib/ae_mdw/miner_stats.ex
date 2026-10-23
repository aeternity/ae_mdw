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
  alias AeMdw.MinerStats.Fold
  alias AeMdw.MinerStats.Folder
  alias AeMdw.Miners
  alias AeMdw.Node
  alias AeMdw.Stats
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type role() :: Model.miner_role()
  @type scope() :: {:gen, Range.t()} | nil
  @type cursor() :: binary() | nil
  @type query() :: %{binary() => binary() | integer()}
  @typep state() :: State.t()
  @typep pagination() :: Collection.direction_limit()
  @typep order_by() :: Model.miner_order_by()

  @roles %{"miner" => :miner, "beneficiary" => :beneficiary}
  @intervals_by %{"day" => :day, "week" => :week, "month" => :month}

  @doc """
  Totals of the whole chain and how far the stats have been folded, since they're built
  in the background from the finalized generations.
  """
  @spec fetch_summary(state()) :: {:ok, map()}
  def fetch_summary(state) do
    summary = %{
      bucket_size: Fold.bucket_size(),
      mdw_height: max(State.height(state), 0),
      stats_height: Folder.folded_height(state),
      last_bucket: nil,
      blocks: 0,
      txs: 0,
      rewards: 0,
      fees: 0,
      miners: 0,
      beneficiaries: 0
    }

    # the keys are sorted by interval, so the one before the days is the last bucket
    case State.prev(state, Model.NetworkBucket, {:day, 0}) do
      {:ok, {:bucket, bucket} = key} ->
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
    order_by = order_by || :blocks

    with {:ok, role, rest} <- split_role(query, :miner),
         :ok <- check_params(rest, []),
         :ok <- check_order(role, order_by),
         {:ok, cursor} <- Miners.deserialize_cursor(cursor) do
      boundary =
        {{role, order_by, Util.min_int(), <<>>}, {role, order_by, Util.max_int(), <<>>}}

      # the cursor is the first miner of the page, so it's kept even if it moved since then
      cursor_key =
        case cursor do
          {value, pk} -> {role, order_by, value, pk}
          nil -> nil
        end

      stream_fn = fn direction ->
        Collection.stream(state, Model.MinerOrder, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        fn {^role, ^order_by, _value, pk} ->
          render_miner(State.fetch!(state, Model.MinerEntity, {role, pk}))
        end,
        fn {_role, _order_by, value, pk} -> Miners.serialize_cursor({value, pk}) end
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_miner(state(), query(), binary()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_miner(state, query, id) do
    with {:ok, role, rest} <- split_role(query),
         :ok <- check_params(rest, []),
         {:ok, pk} <- Validate.id(id, [:account_pubkey]),
         role = detect_role(state, role, pk),
         {:ok, entity} <- found(State.get(state, Model.MinerEntity, {role, pk}), id) do
      {:ok, render_miner(entity)}
    end
  end

  @doc """
  The miner keys that mined for a beneficiary.
  """
  @spec fetch_links(state(), pagination(), query(), binary(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_links(state, pagination, query, id, cursor) do
    with :ok <- check_params(query, []),
         {:ok, beneficiary_pk} <- Validate.id(id, [:account_pubkey]),
         {:ok, cursor_pk} <- deserialize_pubkey_cursor(cursor) do
      boundary = {{beneficiary_pk, <<>>}, {beneficiary_pk, Util.max_256bit_bin()}}
      cursor_key = cursor_pk && {beneficiary_pk, cursor_pk}

      stream_fn = fn direction ->
        Collection.stream(state, Model.BeneficiaryLink, direction, boundary, cursor_key)
      end

      stream_fn
      |> Collection.paginate(
        pagination,
        &render_link(State.fetch!(state, Model.BeneficiaryLink, &1)),
        fn {_beneficiary_pk, miner_pk} -> encode(miner_pk) end
      )
      |> then(&{:ok, &1})
    end
  end

  @doc """
  Series of a miner, one row per bucket (or day, week or month) where it mined or got paid.
  """
  @spec fetch_miner_series(state(), pagination(), binary(), scope(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_miner_series(state, pagination, id, scope, query, cursor) do
    with {:ok, role, rest} <- split_role(query),
         {:ok, pk} <- Validate.id(id, [:account_pubkey]),
         role = detect_role(state, role, pk),
         {:ok, interval, groups} <- series_params(rest, scope) do
      series(
        state,
        pagination,
        groups,
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
    with {:ok, interval, groups} <- series_params(query, scope) do
      series(
        state,
        pagination,
        groups,
        cursor,
        Model.NetworkBucket,
        &{interval, &1},
        &render_network_row(state, &1)
      )
    end
  end

  @spec fetch_bucket(state(), Model.bucket()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_bucket(state, bucket) do
    with {:ok, _row} <-
           found(State.get(state, Model.NetworkBucket, {:bucket, bucket}), "#{bucket}") do
      {:ok, render_network_row(state, {:bucket, bucket})}
    end
  end

  @doc """
  The miners (or beneficiaries) that mined in a bucket.
  """
  @spec fetch_bucket_miners(state(), pagination(), Model.bucket(), query(), cursor()) ::
          {:ok, {cursor(), [map()], cursor()}} | {:error, Error.t()}
  def fetch_bucket_miners(state, pagination, bucket, query, cursor) do
    with {:ok, role, rest} <- split_role(query, :miner),
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
          state
          |> render_miner_row(role, {role, pk, :bucket, bucket})
          |> Map.put(:id, encode(pk))
        end,
        fn {_role, _bucket, pk} -> encode(pk) end
      )
      |> then(&{:ok, &1})
    end
  end

  # Every interval is indexed, with the group in the last place of the key, which is also
  # what the cursor is.
  defp series(state, pagination, {first_group, last_group}, cursor, table, key_fun, render_fun) do
    with {:ok, cursor_group} <- deserialize_group_cursor(cursor) do
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
           fees: fees
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
      fees: fees
    }
  end

  # Only beneficiaries get rewards.
  defp rewards_for(:miner, _rewards), do: nil
  defp rewards_for(:beneficiary, rewards), do: rewards

  defp render_link(
         Model.beneficiary_link(
           index: {_beneficiary_pk, miner_pk},
           blocks: blocks,
           first_height: first_height,
           last_height: last_height
         )
       ) do
    %{id: encode(miner_pk), blocks: blocks, first_height: first_height, last_height: last_height}
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

    Model.network_bucket(
      start_height: start_height,
      end_height: end_height,
      start_time: start_time,
      end_time: end_time
    ) = State.fetch!(state, Model.NetworkBucket, {interval, group})

    interval
    |> period(group)
    |> Map.merge(%{
      start_height: start_height,
      end_height: end_height,
      start_time: start_time,
      end_time: end_time,
      blocks: blocks,
      txs: txs,
      rewards: rewards_for(role, rewards),
      fees: fees,
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_for(role, rewards_total),
      fees_total: fees_total
    })
  end

  defp period(:bucket, group), do: %{bucket: group}

  defp period(interval_by, group) do
    {start_date, end_date} = Stats.interval_dates(interval_by, group)

    %{start_date: start_date, end_date: end_date}
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
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total,
      miners_total: miners_total,
      beneficiaries_total: beneficiaries_total
    ) = State.fetch!(state, Model.NetworkBucket, key)

    interval
    |> period(group)
    |> Map.merge(%{
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
      blocks_total: blocks_total,
      txs_total: txs_total,
      rewards_total: rewards_total,
      fees_total: fees_total,
      miners_total: miners_total,
      beneficiaries_total: beneficiaries_total
    })
  end

  defp avg_block_time(start_time, end_time, blocks) when blocks > 1,
    do: div(end_time - start_time, blocks - 1)

  defp avg_block_time(_start_time, _end_time, _blocks), do: nil

  defp encode(pk), do: Enc.encode(:account_pubkey, pk)

  defp found({:ok, entity}, _id), do: {:ok, entity}
  defp found(:not_found, id), do: {:error, ErrInput.NotFound.exception(value: id)}

  defp split_role(query, default \\ nil) do
    case Map.pop(query, "role") do
      {nil, rest} ->
        {:ok, default, rest}

      {role, rest} ->
        case Map.fetch(@roles, role) do
          {:ok, role} -> {:ok, role, rest}
          :error -> invalid_query("role", role)
        end
    end
  end

  # Miner keys and beneficiaries are both accounts, the miner is used unless there are only
  # stats of the account as a beneficiary.
  defp detect_role(_state, role, _pk) when not is_nil(role), do: role

  defp detect_role(state, nil, pk) do
    cond do
      State.exists?(state, Model.MinerEntity, {:miner, pk}) -> :miner
      State.exists?(state, Model.MinerEntity, {:beneficiary, pk}) -> :beneficiary
      true -> :miner
    end
  end

  defp check_order(role, order_by) do
    if order_by in Fold.orders_by(role),
      do: :ok,
      else: {:error, ErrInput.Query.exception(value: "by=#{order_by}")}
  end

  defp check_params(query, allowed_keys) do
    case Enum.find(query, fn {key, _val} -> key not in allowed_keys end) do
      nil -> :ok
      {key, val} -> invalid_query(key, val)
    end
  end

  defp series_params(query, scope) do
    {interval_by, rest} = Map.pop(query, "interval_by")

    with {:ok, interval} <- convert_interval(interval_by),
         {:ok, groups} <- group_range(interval, scope, rest) do
      {:ok, interval, groups}
    end
  end

  defp convert_interval(nil), do: {:ok, :bucket}

  defp convert_interval(interval_by) when is_binary(interval_by) do
    case Map.fetch(@intervals_by, interval_by) do
      {:ok, interval} -> {:ok, interval}
      :error -> invalid_query("interval_by", interval_by)
    end
  end

  defp convert_interval(interval_by), do: invalid_query("interval_by", interval_by)

  # The buckets are selected by generations and the days, weeks and months by dates.
  defp group_range(:bucket, scope, query) do
    with :ok <- check_params(query, []) do
      case scope do
        nil ->
          {:ok, {0, Util.max_int()}}

        {:gen, first_gen..last_gen//_step} ->
          {:ok, {Fold.bucket(first_gen), Fold.bucket(last_gen)}}
      end
    end
  end

  defp group_range(_interval_by, {:gen, first_gen..last_gen//_step}, _query),
    do: {:error, ErrInput.Scope.exception(value: "gen:#{first_gen}-#{last_gen}")}

  defp group_range(interval_by, nil, query) do
    with :ok <- check_params(query, ["min_start_date", "max_start_date"]),
         {:ok, first_group} <- date_group(query, "min_start_date", interval_by, 0),
         {:ok, last_group} <- date_group(query, "max_start_date", interval_by, Util.max_int()) do
      {:ok, {first_group, last_group}}
    end
  end

  defp date_group(query, key, interval_by, default) do
    with {:ok, date} when is_binary(date) <- Map.fetch(query, key),
         {:ok, date} <- Date.from_iso8601(date) do
      {:ok, Stats.to_interval(date, interval_by)}
    else
      :error -> {:ok, default}
      _invalid -> invalid_query(key, Map.fetch!(query, key))
    end
  end

  @spec parse_bucket(binary() | integer()) :: {:ok, Model.bucket()} | {:error, Error.t()}
  def parse_bucket(bucket) when is_integer(bucket) and bucket >= 0, do: {:ok, bucket}

  def parse_bucket(bucket) when is_binary(bucket) do
    case Integer.parse(bucket) do
      {bucket, ""} -> parse_bucket(bucket)
      _invalid -> invalid_query("bucket", bucket)
    end
  end

  def parse_bucket(bucket), do: invalid_query("bucket", bucket)

  # The params that aren't strings are maps or lists, like role[x]=1.
  defp invalid_query(key, val) when is_binary(val),
    do: {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}

  defp invalid_query(key, val),
    do: {:error, ErrInput.Query.exception(value: "#{key}=#{inspect(val)}")}

  defp deserialize_pubkey_cursor(nil), do: {:ok, nil}

  defp deserialize_pubkey_cursor(cursor) when is_binary(cursor) do
    case Enc.safe_decode(:account_pubkey, cursor) do
      {:ok, pk} -> {:ok, pk}
      {:error, _reason} -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp deserialize_pubkey_cursor(cursor), do: {:error, ErrInput.Cursor.exception(value: cursor)}

  # The group is the last element of the key of the series rows.
  defp serialize_group_cursor(key), do: key |> elem(tuple_size(key) - 1) |> Integer.to_string()

  defp deserialize_group_cursor(nil), do: {:ok, nil}

  defp deserialize_group_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {group, ""} when group >= 0 -> {:ok, group}
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp deserialize_group_cursor(cursor), do: {:error, ErrInput.Cursor.exception(value: cursor)}
end
