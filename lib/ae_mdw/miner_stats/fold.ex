defmodule AeMdw.MinerStats.Fold do
  @moduledoc """
  Folds generations, in order and only once each, into the mining stats tables.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Facts

  require Model

  @bucket_size 20

  @spec bucket_size() :: pos_integer()
  def bucket_size, do: @bucket_size

  @spec bucket(AeMdw.Blocks.height()) :: Model.bucket()
  def bucket(height), do: div(height, @bucket_size)

  @spec fold(State.t(), Facts.t()) :: State.t()
  def fold(state, %{height: height} = facts) do
    bucket = bucket(height)

    {state, miner_tick} = mine(state, :miner, facts.miner, facts, bucket)
    {state, beneficiary_tick} = mine(state, :beneficiary, facts.beneficiary, facts, bucket)

    state
    |> link(facts.miner, facts.beneficiary, height)
    |> credit_rewards(facts.rewards, bucket)
    |> update_network(facts, bucket, miner_tick, beneficiary_tick)
  end

  defp mine(state, role, pk, facts, bucket) do
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

    Model.miner_entity(
      blocks: blocks,
      txs: txs,
      fees: fees,
      last_info: last_info,
      info_changes: info_changes
    ) = entity

    entity =
      Model.miner_entity(entity,
        last_height: facts.height,
        last_time: facts.time,
        blocks: blocks + 1,
        txs: txs + facts.txs,
        fees: fees + facts.fees,
        last_info: facts.info,
        info_changes: info_changes + info_change(new?, last_info, facts.info)
      )

    bucket_key = {role, pk, bucket}
    row = get_bucket_row(state, bucket_key)
    first_in_bucket? = Model.miner_bucket(row, :blocks) == 0

    Model.miner_bucket(blocks: row_blocks, txs: row_txs, fees: row_fees) = row

    row =
      Model.miner_bucket(row,
        blocks: row_blocks + 1,
        txs: row_txs + facts.txs,
        fees: row_fees + facts.fees
      )

    state =
      state
      |> State.put(Model.MinerEntity, entity)
      |> put_bucket_row(row, entity)

    {state, %{new?: new?, first_in_bucket?: first_in_bucket?, blocks: row_blocks + 1}}
  end

  defp info_change(true, _last_info, _info), do: 0
  defp info_change(false, info, info), do: 0
  defp info_change(false, _last_info, _info), do: 1

  defp link(state, miner_pk, beneficiary_pk, height) do
    link_key = {miner_pk, beneficiary_pk}

    link =
      case State.get(state, Model.MinerLink, link_key) do
        {:ok, Model.miner_link(blocks: blocks) = link} ->
          Model.miner_link(link, blocks: blocks + 1, last_height: height)

        :not_found ->
          Model.miner_link(index: link_key, blocks: 1, first_height: height, last_height: height)
      end

    state
    |> State.put(Model.MinerLink, link)
    |> State.put(Model.BeneficiaryLink, Model.beneficiary_link(index: {beneficiary_pk, miner_pk}))
  end

  # Rewards are only received by beneficiaries, for blocks mined some generations ago
  # so it doesn't make them active nor moves their last activity.
  defp credit_rewards(state, rewards, bucket) do
    Enum.reduce(rewards, state, fn {beneficiary_pk, amount}, state ->
      entity_key = {:beneficiary, beneficiary_pk}

      entity =
        case State.get(state, Model.MinerEntity, entity_key) do
          {:ok, entity} -> entity
          :not_found -> Model.miner_entity(index: entity_key)
        end

      entity = Model.miner_entity(entity, rewards: Model.miner_entity(entity, :rewards) + amount)

      row = get_bucket_row(state, {:beneficiary, beneficiary_pk, bucket})
      row = Model.miner_bucket(row, rewards: Model.miner_bucket(row, :rewards) + amount)

      state
      |> State.put(Model.MinerEntity, entity)
      |> put_bucket_row(row, entity)
    end)
  end

  defp get_bucket_row(state, bucket_key) do
    case State.get(state, Model.MinerBucket, bucket_key) do
      {:ok, row} -> row
      :not_found -> Model.miner_bucket(index: bucket_key)
    end
  end

  defp put_bucket_row(state, row, entity) do
    {role, pk, bucket} = Model.miner_bucket(row, :index)

    Model.miner_entity(blocks: blocks, txs: txs, rewards: rewards, fees: fees) = entity

    row =
      Model.miner_bucket(row,
        blocks_total: blocks,
        txs_total: txs,
        rewards_total: rewards,
        fees_total: fees
      )

    state = State.put(state, Model.MinerBucket, row)

    # only the ones that mined in the bucket, not the ones that were just paid
    if Model.miner_bucket(row, :blocks) > 0 do
      State.put(state, Model.BucketMiner, Model.bucket_miner(index: {role, bucket, pk}))
    else
      state
    end
  end

  defp update_network(state, facts, bucket, miner_tick, beneficiary_tick) do
    row = get_network_row(state, bucket, facts)
    reward = facts.rewards |> Map.values() |> Enum.sum()
    new_miners = tick(miner_tick.new?)
    new_beneficiaries = tick(beneficiary_tick.new?)

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
        active_miners:
          Model.network_bucket(row, :active_miners) + tick(miner_tick.first_in_bucket?),
        active_beneficiaries:
          Model.network_bucket(row, :active_beneficiaries) +
            tick(beneficiary_tick.first_in_bucket?),
        new_miners: Model.network_bucket(row, :new_miners) + new_miners,
        new_beneficiaries: Model.network_bucket(row, :new_beneficiaries) + new_beneficiaries,
        top_miner_blocks: max(Model.network_bucket(row, :top_miner_blocks), miner_tick.blocks),
        top_beneficiary_blocks:
          max(Model.network_bucket(row, :top_beneficiary_blocks), beneficiary_tick.blocks),
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

  # A new bucket starts from the totals at the end of the previous one.
  defp get_network_row(state, bucket, facts) do
    case State.get(state, Model.NetworkBucket, bucket) do
      {:ok, row} ->
        row

      :not_found ->
        base =
          case State.get(state, Model.NetworkBucket, bucket - 1) do
            {:ok, previous} -> previous
            :not_found -> Model.network_bucket()
          end

        Model.network_bucket(
          index: bucket,
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
