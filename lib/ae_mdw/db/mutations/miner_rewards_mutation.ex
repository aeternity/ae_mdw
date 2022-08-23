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
      {state, new_miner?} =
        case State.get(state, Model.Miner, beneficiary_pk) do
          {:ok, Model.miner(total_reward: old_reward) = miner} ->
            {State.put(state, Model.Miner, Model.miner(miner, total_reward: old_reward + reward)),
             false}

          :not_found ->
            {State.put(
               state,
               Model.Miner,
               Model.miner(index: beneficiary_pk, total_reward: reward)
             ), true}
        end

      if new_miner? do
        State.update(state, Model.Stat, Stats.miners_count_key(), fn
          Model.stat(payload: count) = stat ->
            Model.stat(stat, payload: count + 1)

          nil ->
            Model.stat(index: Stats.miners_count_key(), payload: 1)
        end)
      else
        state
      end
    end)
  end
end
