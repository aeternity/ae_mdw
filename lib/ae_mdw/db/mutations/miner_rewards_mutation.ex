defmodule AeMdw.Db.MinerRewardsMutation do
  @moduledoc """
  Adds reward given to a miner and increases the miners count.
  """

  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:rewards]

  @opaque t() :: %__MODULE__{rewards: IntTransfer.rewards()}

  @spec new(IntTransfer.rewards()) :: t()
  def new(rewards), do: %__MODULE__{rewards: rewards}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{rewards: rewards}, state) do
    Enum.reduce(rewards, state, fn {beneficiary_pk, reward}, state ->
      {state, new_miner?} = increment_total_reward(state, beneficiary_pk, reward)

      if new_miner? do
        increment_miners_count(state)
      else
        state
      end
    end)
  end

  defp increment_total_reward(state, beneficiary_pk, reward) do
    case State.get(state, Model.Miner, beneficiary_pk) do
      {:ok, Model.miner(total_reward: old_reward) = miner} ->
        total_reward = old_reward + reward

        state
        |> State.put(
          Model.Miner,
          Model.miner(miner, total_reward: total_reward)
        )
        |> State.delete(Model.RewardMiner, {old_reward, beneficiary_pk})
        |> State.put(
          Model.RewardMiner,
          Model.reward_miner(index: {total_reward, beneficiary_pk})
        )
        |> then(fn st ->
          {st, false}
        end)

      :not_found ->
        state
        |> State.put(
          Model.RewardMiner,
          Model.reward_miner(index: {reward, beneficiary_pk})
        )
        |> State.put(
          Model.Miner,
          Model.miner(index: beneficiary_pk, total_reward: reward)
        )
        |> then(fn st ->
          {st, true}
        end)
    end
  end

  defp increment_miners_count(state) do
    key = Stats.miners_count_key()

    State.update(
      state,
      Model.Stat,
      key,
      fn
        Model.stat(payload: count) = stat -> Model.stat(stat, payload: count + 1)
      end,
      Model.stat(index: key, payload: 0)
    )
  end
end
