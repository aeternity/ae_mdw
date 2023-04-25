defmodule AeMdw.Migrations.UpdateTotalSupply do
  @moduledoc """
  Updates totalstats total supply incrementing with the lima contracts amount.
  """

  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    with [%{amount: amount}] <- :aec_fork_block_settings.lima_contracts(),
         {:ok, {last_height, _mbi}} <- State.prev(state, Model.Block, nil),
         %{4 => lima_height} <-
           :aec_hard_forks.protocols_from_network_id(:aec_governance.get_network_id()) do
      mutations =
        Enum.map(lima_height..last_height, fn height ->
          m_stat =
            Model.total_stat(total_supply: total_supply) =
            State.fetch!(state, Model.TotalStat, height)

          WriteMutation.new(
            Model.TotalStat,
            Model.total_stat(m_stat, total_supply: total_supply + amount)
          )
        end)

      _state = State.commit(state, mutations)

      {:ok, length(mutations)}
    else
      _no_lima ->
        {:ok, 0}
    end
  end
end
