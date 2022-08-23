defmodule AeMdw.Migrations.AddMiners do
  @moduledoc """
  Add miners to Model.Miner table and the total miners count in stats.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Stats

  require Model

  @log_freq 1_000

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    state = State.new()

    case state |> Collection.stream(Model.DeltaStat, :backward, nil, nil) |> Enum.take(1) do
      [total_gens] -> run_with_gens(state, total_gens)
      [] -> {:ok, {0, 0}}
    end
  end

  defp run_with_gens(state, total_gens) do
    begin = DateTime.utc_now()

    mutations =
      0..total_gens
      |> Enum.reduce(%{}, fn height, miners_acc ->
        if rem(height, @log_freq) == 0, do: IO.puts("Processed #{height} of #{total_gens}")

        state
        |> Collection.stream(
          Model.KindIntTransferTx,
          {"reward_block", {height, -1}, <<>>, nil}
        )
        |> Stream.take_while(&match?({"reward_block", {^height, -1}, _target_pk, _ref_txi}, &1))
        |> Stream.map(fn {kind, block_index, beneficiary_pk, ref_txi} ->
          Model.int_transfer_tx(amount: reward) =
            State.fetch!(
              state,
              Model.IntTransferTx,
              {block_index, kind, beneficiary_pk, ref_txi}
            )

          {beneficiary_pk, reward}
        end)
        |> Enum.reduce(miners_acc, fn {beneficiary_pk, reward}, miners_acc ->
          Map.update(miners_acc, beneficiary_pk, reward, &(&1 + reward))
        end)
      end)
      |> Enum.map(fn {miner_pk, total_reward} ->
        WriteMutation.new(Model.Miner, Model.miner(index: miner_pk, total_reward: total_reward))
      end)

    stat_mutation =
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.miners_count_key(), payload: length(mutations))
      )

    State.commit(state, [stat_mutation | mutations])

    IO.puts("DONE")

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {total_gens, duration}}
  end
end
