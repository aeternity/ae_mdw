defmodule AeMdw.Db.MinerRewardsMutation do
  @moduledoc """
  Adds reward given to a miner and increases the miners count.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db
  alias AeMdw.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height, :rewards, :current_miner, :current_beneficiary, :delay]

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            rewards: IntTransfer.rewards(),
            current_miner: Db.pubkey(),
            current_beneficiary: Db.pubkey(),
            delay: non_neg_integer()
          }

  @spec new(Blocks.height(), IntTransfer.rewards(), Db.pubkey(), Db.pubkey(), non_neg_integer()) ::
          t()
  def new(height, rewards, current_miner, current_beneficiary, delay) do
    %__MODULE__{
      height: height,
      rewards: rewards,
      current_miner: current_miner,
      current_beneficiary: current_beneficiary,
      delay: delay
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          height: height,
          rewards: rewards,
          current_miner: current_miner,
          current_beneficiary: current_beneficiary,
          delay: delay
        },
        state
      ) do
    beneficiaries_miner =
      %{current_beneficiary => current_miner}
      |> add_beneficiary(state, height - delay)
      |> add_beneficiary(state, height - delay - 1)

    Enum.reduce(rewards, state, fn {beneficiary_pk, reward}, state ->
      miner_pk = Map.fetch!(beneficiaries_miner, beneficiary_pk)

      {state, new_miner?} =
        case State.get(state, Model.Miner, miner_pk) do
          {:ok, Model.miner(total_reward: old_reward) = miner} ->
            {State.put(state, Model.Miner, Model.miner(miner, total_reward: old_reward + reward)),
             false}

          :not_found ->
            {State.put(state, Model.Miner, Model.miner(index: miner_pk, total_reward: reward)),
             true}
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

  defp add_beneficiary(beneficiaries_miner, state, height) do
    case State.get(state, Model.Block, {height, -1}) do
      {:ok, Model.block(hash: kb_hash)} ->
        key_block = :aec_db.get_block(kb_hash)
        key_header = :aec_blocks.to_header(key_block)

        Map.put(
          beneficiaries_miner,
          :aec_headers.beneficiary(key_header),
          :aec_headers.miner(key_header)
        )

      :not_found ->
        beneficiaries_miner
    end
  end
end
