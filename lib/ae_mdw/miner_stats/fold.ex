defmodule AeMdw.MinerStats.Fold do
  @moduledoc """
  Folds generations, in order and only once each, into the mining stats tables.

  Generations are grouped in buckets and the series are kept for each of the intervals
  (a number of consecutive buckets), updating all of them when folding, so any of them can
  be read without merging rows.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Facts

  require Model

  @bucket_size 20
  # of buckets, which is about an hour, a day, a week, a month and a year
  @intervals [1, 24, 168, 720, 8760]

  @spec bucket_size() :: pos_integer()
  def bucket_size, do: @bucket_size

  @spec intervals() :: [Model.interval()]
  def intervals, do: @intervals

  @spec bucket(Blocks.height()) :: Model.bucket()
  def bucket(height), do: div(height, @bucket_size)

  @spec fold(State.t(), Facts.t()) :: State.t()
  def fold(state, %{height: height} = facts) do
    {state, miner_new?} = mine(state, :miner, facts.miner, facts)
    {state, beneficiary_new?} = mine(state, :beneficiary, facts.beneficiary, facts)
    state = state |> link(facts.miner, facts.beneficiary, height) |> credit_rewards(facts.rewards)

    ctx = %{
      facts: facts,
      miner: {entity!(state, :miner, facts.miner), miner_new?},
      beneficiary: {entity!(state, :beneficiary, facts.beneficiary), beneficiary_new?},
      paid:
        Enum.map(facts.rewards, fn {pk, amount} -> {entity!(state, :beneficiary, pk), amount} end)
    }

    Enum.reduce(@intervals, state, &fold_interval(&2, ctx, &1))
  end

  defp mine(state, role, pk, facts) do
    entity_key = {role, pk}

    {new?, entity} =
      case State.get(state, Model.MinerEntity, entity_key) do
        {:ok, entity} ->
          {false, entity}

        :not_found ->
          {true,
           Model.miner_entity(
             index: entity_key,
             first_height: facts.height,
             first_time: facts.time
           )}
      end

    Model.miner_entity(blocks: blocks, txs: txs, fees: fees) = entity

    entity =
      Model.miner_entity(entity,
        last_height: facts.height,
        last_time: facts.time,
        blocks: blocks + 1,
        txs: txs + facts.txs,
        fees: fees + facts.fees
      )

    {State.put(state, Model.MinerEntity, entity), new?}
  end

  defp link(state, miner_pk, beneficiary_pk, height) do
    link_key = {beneficiary_pk, miner_pk}

    link =
      case State.get(state, Model.BeneficiaryLink, link_key) do
        {:ok, Model.beneficiary_link(blocks: blocks) = link} ->
          Model.beneficiary_link(link, blocks: blocks + 1, last_height: height)

        :not_found ->
          Model.beneficiary_link(
            index: link_key,
            blocks: 1,
            first_height: height,
            last_height: height
          )
      end

    State.put(state, Model.BeneficiaryLink, link)
  end

  # Rewards are only received by beneficiaries, for blocks mined some generations ago
  # so it doesn't make them active nor moves their last activity.
  defp credit_rewards(state, rewards) do
    Enum.reduce(rewards, state, fn {beneficiary_pk, amount}, state ->
      entity_key = {:beneficiary, beneficiary_pk}

      entity =
        case State.get(state, Model.MinerEntity, entity_key) do
          {:ok, entity} -> entity
          :not_found -> Model.miner_entity(index: entity_key)
        end

      entity = Model.miner_entity(entity, rewards: Model.miner_entity(entity, :rewards) + amount)

      State.put(state, Model.MinerEntity, entity)
    end)
  end

  defp entity!(state, role, pk), do: State.fetch!(state, Model.MinerEntity, {role, pk})

  defp fold_interval(state, %{facts: facts} = ctx, interval) do
    group = div(bucket(facts.height), interval)
    {miner_entity, miner_new?} = ctx.miner
    {beneficiary_entity, beneficiary_new?} = ctx.beneficiary

    {state, miner_first?} = mine_row(state, miner_entity, interval, group, facts)
    {state, beneficiary_first?} = mine_row(state, beneficiary_entity, interval, group, facts)

    state
    |> credit_rows(ctx.paid, interval, group)
    |> update_network(
      facts,
      {interval, group},
      {miner_first?, miner_new?},
      {beneficiary_first?, beneficiary_new?}
    )
  end

  defp mine_row(state, entity, interval, group, facts) do
    {role, pk} = Model.miner_entity(entity, :index)
    row = get_row(state, {role, pk, interval, group})
    first_in_group? = Model.miner_bucket(row, :blocks) == 0

    Model.miner_bucket(blocks: blocks, txs: txs, fees: fees) = row

    row =
      Model.miner_bucket(row,
        blocks: blocks + 1,
        txs: txs + facts.txs,
        fees: fees + facts.fees
      )

    {put_row(state, row, entity), first_in_group?}
  end

  defp credit_rows(state, paid, interval, group) do
    Enum.reduce(paid, state, fn {entity, amount}, state ->
      {:beneficiary, pk} = Model.miner_entity(entity, :index)
      row = get_row(state, {:beneficiary, pk, interval, group})
      row = Model.miner_bucket(row, rewards: Model.miner_bucket(row, :rewards) + amount)

      put_row(state, row, entity)
    end)
  end

  defp get_row(state, row_key) do
    case State.get(state, Model.MinerBucket, row_key) do
      {:ok, row} -> row
      :not_found -> Model.miner_bucket(index: row_key)
    end
  end

  defp put_row(state, row, entity) do
    {role, pk, interval, group} = Model.miner_bucket(row, :index)

    Model.miner_entity(blocks: blocks, txs: txs, rewards: rewards, fees: fees) = entity

    row =
      Model.miner_bucket(row,
        blocks_total: blocks,
        txs_total: txs,
        rewards_total: rewards,
        fees_total: fees
      )

    state = State.put(state, Model.MinerBucket, row)

    # only the ones that mined in the group, not the ones that were just paid
    if Model.miner_bucket(row, :blocks) > 0 do
      State.put(
        state,
        Model.BucketMiner,
        Model.bucket_miner(index: {role, interval, group, pk})
      )
    else
      state
    end
  end

  defp update_network(
         state,
         facts,
         row_key,
         {miner_first?, miner_new?},
         {beneficiary_first?, beneficiary_new?}
       ) do
    row = get_network_row(state, row_key, facts)
    reward = facts.rewards |> Map.values() |> Enum.sum()
    new_miners = tick(miner_new?)
    new_beneficiaries = tick(beneficiary_new?)

    row =
      Model.network_bucket(row,
        end_height: facts.height,
        end_time: facts.time,
        blocks: Model.network_bucket(row, :blocks) + 1,
        micro_blocks: Model.network_bucket(row, :micro_blocks) + facts.micro_blocks,
        txs: Model.network_bucket(row, :txs) + facts.txs,
        rewards: Model.network_bucket(row, :rewards) + reward,
        fees: Model.network_bucket(row, :fees) + facts.fees,
        difficulty_sum: Model.network_bucket(row, :difficulty_sum) + facts.difficulty,
        active_miners: Model.network_bucket(row, :active_miners) + tick(miner_first?),
        active_beneficiaries:
          Model.network_bucket(row, :active_beneficiaries) + tick(beneficiary_first?),
        new_miners: Model.network_bucket(row, :new_miners) + new_miners,
        new_beneficiaries: Model.network_bucket(row, :new_beneficiaries) + new_beneficiaries,
        blocks_total: Model.network_bucket(row, :blocks_total) + 1,
        txs_total: Model.network_bucket(row, :txs_total) + facts.txs,
        rewards_total: Model.network_bucket(row, :rewards_total) + reward,
        fees_total: Model.network_bucket(row, :fees_total) + facts.fees,
        miners_total: Model.network_bucket(row, :miners_total) + new_miners,
        beneficiaries_total: Model.network_bucket(row, :beneficiaries_total) + new_beneficiaries
      )

    State.put(state, Model.NetworkBucket, row)
  end

  defp tick(true), do: 1
  defp tick(false), do: 0

  # A new group starts from the totals at the end of the previous one.
  defp get_network_row(state, {interval, group} = row_key, facts) do
    case State.get(state, Model.NetworkBucket, row_key) do
      {:ok, row} ->
        row

      :not_found ->
        base =
          case State.get(state, Model.NetworkBucket, {interval, group - 1}) do
            {:ok, previous} -> previous
            :not_found -> Model.network_bucket()
          end

        Model.network_bucket(
          index: row_key,
          start_height: facts.height,
          start_time: facts.time,
          blocks_total: Model.network_bucket(base, :blocks_total),
          txs_total: Model.network_bucket(base, :txs_total),
          rewards_total: Model.network_bucket(base, :rewards_total),
          fees_total: Model.network_bucket(base, :fees_total),
          miners_total: Model.network_bucket(base, :miners_total),
          beneficiaries_total: Model.network_bucket(base, :beneficiaries_total)
        )
    end
  end
end
