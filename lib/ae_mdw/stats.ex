defmodule AeMdw.Stats do
  @moduledoc """
  Context module for dealing with Stats.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Database
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

  @type stat() :: map()
  @type delta_stat() :: map()
  @type total_stat() :: map()
  @type cursor() :: binary() | nil
  @type tps() :: non_neg_integer()

  @typep txi() :: Blocks.height()
  @typep pubkey() :: Db.pubkey()
  @typep height() :: Blocks.height()
  @typep direction() :: Database.direction()
  @typep limit() :: Database.limit()
  @typep range() :: {:gen, Range.t()} | nil
  @typep aexn_type() :: :aex9 | :aex141

  @type nft_stats :: %{nfts_amount: non_neg_integer(), nft_owners: non_neg_integer()}
  @typep template_id() :: AeMdw.Aex141.template_id()
  @tps_stat_key :max_tps
  @miners_count_stat_key :miners_count
  @nfts_count_stat :nfts_count
  @nft_owners_count_stat :nft_owners_count
  @nft_template_tokens_stat :nft_template_tokens_count
  @aex9_count_stat :aex9_count
  @aex9_holder_count_stat :aex9_holder_count
  @aex9_logs_count_stat :aex9_logs_count
  @aex141_count_stat :aex141_count

  @spec mutation(height(), Db.key_block(), [Db.micro_block()], txi(), txi(), boolean()) ::
          StatsMutation.t()
  def mutation(height, key_block, micro_blocks, from_txi, next_txi, starting_from_mb0?) do
    header = :aec_blocks.to_header(key_block)
    time = :aec_headers.time_in_msecs(header)
    {:ok, key_hash} = :aec_headers.hash_header(header)

    {_last_time, total_time, total_txs} =
      Enum.reduce(micro_blocks, {time, 0, 0}, fn micro_block, {last_time, time_acc, count_acc} ->
        header = :aec_blocks.to_header(micro_block)
        time = :aec_headers.time_in_msecs(header)
        count = length(:aec_blocks.txs(micro_block))

        {time, time_acc + time - last_time, count_acc + count}
      end)

    tps = if total_time > 0, do: round(total_txs * 100_000 / total_time) / 100, else: 0

    StatsMutation.new(height, key_hash, from_txi, next_txi, tps, starting_from_mb0?)
  end

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

  # Legacy v1 is a blending between /totalstats and /deltastats.
  # The active and inactive object counters are totals while the rewards are delta.
  @spec fetch_stats_v1(State.t(), direction(), range(), cursor(), limit()) ::
          {cursor(), [stat()], cursor()}
  def fetch_stats_v1(state, direction, range, cursor, limit) do
    {:ok, last_gen} = State.prev(state, Model.TotalStat, nil)

    range =
      case range do
        nil -> {1, last_gen}
        {:gen, first..last} -> {max(first, 1), last}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range, limit, last_gen) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_stats(state, range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_delta_stats(State.t(), direction(), range(), cursor(), limit()) ::
          {cursor(), [delta_stat()], cursor()}
  def fetch_delta_stats(state, direction, range, cursor, limit) do
    cursor = deserialize_cursor(cursor)

    with {:ok, last_gen} <- State.prev(state, Model.DeltaStat, nil),
         scope <- deserialize_scope(range, last_gen),
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
         scope <- deserialize_scope(range, last_gen),
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
         {:ok, Model.stat(payload: miners_count)} <-
           State.get(state, Model.Stat, @miners_count_stat_key) do
      {:ok,
       %{
         max_transactions_per_second: tps,
         max_transactions_per_second_block_hash: Enc.encode(:key_block_hash, tps_block_hash),
         miners_count: miners_count
       }}
    else
      :not_found ->
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

  defp render_stats(state, first..last) do
    Enum.map(first..last, fn height ->
      %{
        block_reward: block_reward,
        dev_reward: dev_reward
      } = fetch_delta_stat!(state, height - 1)

      %{
        active_auctions: active_auctions,
        active_names: active_names,
        inactive_names: inactive_names,
        active_oracles: active_oracles,
        inactive_oracles: inactive_oracles,
        contracts: contracts
      } = fetch_total_stat!(state, height)

      %{
        height: height,
        block_reward: block_reward,
        dev_reward: dev_reward,
        active_auctions: active_auctions,
        active_names: active_names,
        inactive_names: inactive_names,
        active_oracles: active_oracles,
        inactive_oracles: inactive_oracles,
        contracts: contracts
      }
    end)
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

  defp deserialize_scope(nil, last_gen), do: {1, last_gen}
  defp deserialize_scope({:gen, first..last}, _last_gen), do: {max(first, 1), last}

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
end
