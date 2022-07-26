defmodule AeMdw.Db.IntTransfersMutation do
  @moduledoc """
  Saves internal transfers generated or migrated into the blockchain including block and dev rewards.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State

  @derive AeMdw.Db.Mutation
  defstruct [:height, :transfers]

  @type transfer() :: {IntTransfer.kind(), IntTransfer.target(), IntTransfer.amount()}

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            transfers: [transfer()]
          }

  @ref_txi -1
  @txi_pos -1

  @spec new(Blocks.height(), [transfer()]) :: t()
  def new(height, transfers) do
    %__MODULE__{height: height, transfers: transfers}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height, transfers: transfers}, state) do
    gen_txi_pos = {height, @txi_pos}

    Enum.reduce(transfers, state, fn {kind, target_pk, amount}, state ->
      new_state = IntTransfer.write(state, gen_txi_pos, kind, target_pk, @ref_txi, amount)

      if kind in ["reward_dev", "reward_block"] do
        stat_kind = if kind == "reward_dev", do: :dev_reward, else: :block_reward
        State.inc_stat(new_state, stat_kind, amount)
      else
        new_state
      end
    end)
  end
end
