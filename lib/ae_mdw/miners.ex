defmodule AeMdw.Miners do
  @moduledoc """
  Context module for dealing with Miners.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.EtsCache
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

  @type miner() :: map()
  @type cursor() :: binary() | nil
  @type query() :: %{binary() => binary()}
  @typep period() :: :day | :week | :month
  @typep state() :: State.t()
  @typep pubkey() :: Db.pubkey()
  @typep pagination() :: Collection.direction_limit()
  @typep reward_key() :: {non_neg_integer(), pubkey()}

  @periods %{"day" => :day, "week" => :week, "month" => :month}
  @period_msecs %{
    day: :timer.hours(24),
    week: :timer.hours(24 * 7),
    month: :timer.hours(24 * 30)
  }

  @cache_table :miners_period_rewards
  @cache_expiration_minutes 10

  @spec init_cache() :: :ok
  def init_cache, do: EtsCache.new(@cache_table, @cache_expiration_minutes)

  @doc """
  Lists the miners sorted by their total rewards. With the `period` query param
  (day, week or month) it only counts the rewards paid in that last period instead.
  """
  @spec fetch_miners(state(), pagination(), query(), cursor()) ::
          {:ok, {cursor(), [miner()], cursor()}} | {:error, Error.t()}
  def fetch_miners(state, pagination, query, cursor) do
    with {:ok, filters} <- Util.convert_params(query, &convert_param/1),
         {:ok, cursor} <- deserialize_cursor(cursor) do
      state
      |> build_streamer(Map.get(filters, :period), cursor)
      |> Collection.paginate(pagination, &render_miner/1, &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  defp build_streamer(state, nil, cursor),
    do: &Collection.stream(state, Model.RewardMiner, &1, nil, cursor)

  defp build_streamer(state, period, cursor) do
    rewards = period_rewards(state, period)

    fn
      :forward -> drop_before(rewards, cursor)
      :backward -> rewards |> Enum.reverse() |> drop_after(cursor)
    end
  end

  # The cursor is the first record of the page, so it's kept (even if it's gone by now).
  defp drop_before(rewards, nil), do: rewards
  defp drop_before(rewards, cursor), do: Enum.drop_while(rewards, &(&1 < cursor))

  defp drop_after(rewards, nil), do: rewards
  defp drop_after(rewards, cursor), do: Enum.drop_while(rewards, &(&1 > cursor))

  # Ascending list of {reward, miner_pk}, cached per period and chain tip since it
  # sums every block reward in the period but only changes with a new key block.
  @spec period_rewards(state(), period()) :: [reward_key()]
  defp period_rewards(state, period) do
    case DbUtil.last_gen_and_time(state) do
      {:ok, {top_height, top_time}} ->
        cache_key = {period, top_height, key_block_hash(state, top_height)}

        case EtsCache.get(@cache_table, cache_key) do
          {rewards, _inserted_at} ->
            rewards

          nil ->
            rewards =
              compute_period_rewards(state, top_height, top_time - @period_msecs[period])

            EtsCache.put(@cache_table, cache_key, rewards)
            rewards
        end

      :no_blocks ->
        []
    end
  end

  defp key_block_hash(state, height) do
    case State.get(state, Model.Block, {height, -1}) do
      {:ok, Model.block(hash: hash)} -> hash
      :not_found -> nil
    end
  end

  defp compute_period_rewards(state, top_height, since_time) do
    with {:ok, key_block_time} <- State.next(state, Model.KeyBlockTime, since_time),
         {:ok, Model.key_block_time(height: first_height)} <-
           State.get(state, Model.KeyBlockTime, key_block_time) do
      state
      |> IntTransfer.sum_block_rewards_by_target(first_height, top_height)
      |> Enum.map(fn {miner_pk, reward} -> {reward, miner_pk} end)
      |> Enum.sort()
    else
      _no_key_blocks_in_period -> []
    end
  end

  defp render_miner({total_reward, miner_pk}) do
    %{
      miner: Enc.encode(:account_pubkey, miner_pk),
      total_reward: total_reward
    }
  end

  defp convert_param({"period", period}) do
    case Map.fetch(@periods, period) do
      {:ok, period} -> {:ok, {:period, period}}
      :error -> {:error, ErrInput.Query.exception(value: "period=#{period}")}
    end
  end

  defp convert_param({key, val}), do: {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}

  defp serialize_cursor({total_reward, miner_pk}) do
    {total_reward, miner_pk}
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {total_reward, <<miner_pk::256>>}
         when is_integer(total_reward) <-
           :erlang.binary_to_term(cursor_bin, [:safe]) do
      {:ok, {total_reward, <<miner_pk::256>>}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_hex)}
  end
end
