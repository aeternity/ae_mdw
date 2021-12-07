defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.Stat table.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Ets
  alias AeMdw.Mnesia

  require Model

  defstruct [:height, :prev_stat, :prev_sum_stat, :token_supply_delta]

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            prev_stat: Model.stat(),
            prev_sum_stat: Model.sum_stat(),
            token_supply_delta: integer()
          }

  @spec new(Blocks.height(), Model.stat(), Model.sum_stat(), integer()) :: t()
  def new(height, prev_stat, prev_sum_stat, token_supply_delta) do
    %__MODULE__{
      height: height,
      prev_stat: prev_stat,
      prev_sum_stat: prev_sum_stat,
      token_supply_delta: token_supply_delta
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        height: height,
        prev_stat: prev_stat,
        prev_sum_stat: prev_sum_stat,
        token_supply_delta: token_supply_delta
      }) do
    stat =
      Model.stat(prev_stat,
        index: height,
        inactive_names: get(:inactive_names, 0),
        active_names: get(:active_names, 0),
        active_auctions: get(:active_auctions, 0),
        inactive_oracles: get(:inactive_oracles, 0),
        active_oracles: get(:active_oracles, 0),
        contracts: get(:contracts, 0),
        block_reward: get(:block_reward, 0),
        dev_reward: get(:dev_reward, 0)
      )

    Mnesia.write(Model.Stat, stat)

    Model.sum_stat(
      block_reward: prev_block_reward,
      dev_reward: prev_dev_reward,
      total_supply: prev_total_supply
    ) = prev_sum_stat

    inc_block_reward = get(:block_reward, 0)
    inc_dev_reward = get(:dev_reward, 0)

    sum_stat =
      Model.sum_stat(
        index: height,
        block_reward: prev_block_reward + inc_block_reward,
        dev_reward: prev_dev_reward + inc_dev_reward,
        total_supply: prev_total_supply + token_supply_delta + inc_block_reward + inc_dev_reward
      )

    Mnesia.write(Model.SumStat, sum_stat)
  end

  defp get(stat_sync_key, default), do: Ets.get(:stat_sync_cache, stat_sync_key, default)
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.StatsMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
