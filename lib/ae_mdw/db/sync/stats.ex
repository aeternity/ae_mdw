defmodule AeMdw.Db.Sync.Stats do
  @moduledoc """
  Update general and per contract stats during the syncing process.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Node
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep template_id :: AeMdw.Aex141.template_id()
  @typep aexn_type :: :aex9 | :aex141
  @typep time() :: Blocks.time()
  @typep type_counts() :: %{Node.tx_type() => pos_integer()}

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

  @spec decrement_aex9_holders(State.t(), pubkey()) :: State.t()
  def decrement_aex9_holders(state, contract_pk),
    do: update_stat_counter(state, Stats.aex9_holder_count_key(contract_pk), &(&1 - 1))

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

  @spec txs_statistics_mutations(time(), type_counts()) :: StatisticsMutation.t() | nil
  def txs_statistics_mutations(time, type_counts) do
    total_count =
      Enum.reduce(type_counts, 0, fn {_tx_type, increment}, acc -> acc + increment end)

    if total_count > 0 do
      time
      |> time_intervals()
      |> Enum.flat_map(fn {interval, interval_start} ->
        tx_type_statistics =
          Enum.map(type_counts, fn {tx_type, count} ->
            {{{:transactions, tx_type}, interval, interval_start}, count}
          end)

        total_statistic = {{{:transactions, :all}, interval, interval_start}, total_count}

        [total_statistic | tx_type_statistics]
      end)
      |> StatisticsMutation.new()
    else
      nil
    end
  end

  defp time_intervals(time) do
    seconds = div(time, 1_000)
    %DateTime{year: year, month: month} = DateTime.from_unix!(seconds)
    day_start = div(seconds, @seconds_per_day)
    week_start = div(day_start, 7)
    month_start = (year - @start_unix) * 12 + month

    [
      {:day, day_start},
      {:week, week_start},
      {:month, month_start}
    ]
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
