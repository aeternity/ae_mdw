defmodule AeMdw.Db.Sync.Stat do
  @moduledoc """
  Build the stat mutation for a specific generation.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Util

  require Model

  @spec store_mutation(Blocks.height()) :: StatsMutation.t()
  def store_mutation(height) do
    token_supply_delta = AeMdw.Node.token_supply_delta(height + 1)

    StatsMutation.new(height + 1, get_stat(height), get_sum_stat(height), token_supply_delta)
  end

  defp get_stat(height) when height > 0,
    do: Util.read!(Model.Stat, height)

  defp get_stat(0),
    do: Model.stat(index: 0)

  defp get_sum_stat(height) when height >= 0,
    do: Util.read!(Model.SumStat, height)
end
