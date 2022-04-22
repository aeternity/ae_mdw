defmodule AeMdw.Db.BlockRewardsMutation do
  @moduledoc """
  Computes and derives Aex9 tokens, and stores it into the appropriate indexes.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State

  @derive AeMdw.Db.Mutation
  defstruct [:height, :block_rewards]

  @type block_reward() :: {IntTransfer.kind(), IntTransfer.target(), IntTransfer.amount()}

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            block_rewards: [block_reward()]
          }

  @ref_txi -1
  @txi_pos -1

  @spec new(Blocks.height(), [block_reward()]) :: t()
  def new(height, block_rewards) do
    %__MODULE__{height: height, block_rewards: block_rewards}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height, block_rewards: block_rewards}, state) do
    gen_txi_pos = {height, @txi_pos}

    Enum.reduce(block_rewards, state, fn {kind, target_pk, amount}, state ->
      state
      |> IntTransfer.write(gen_txi_pos, kind, target_pk, @ref_txi, amount)
      |> State.inc_stat((kind == "reward_dev" && :dev_reward) || :block_reward, amount)
    end)
  end
end
