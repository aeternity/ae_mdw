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
    delay = :aec_governance.beneficiary_reward_delay()

    {miners, _beneficiaries} =
      0..total_gens
      |> Enum.reduce({%{}, %{}}, fn height, {miners_acc, beneficiaries_heights_miner} ->
        Model.block(hash: kb_hash) = State.fetch!(state, Model.Block, {height, -1})
        key_block = :aec_db.get_block(kb_hash)
        key_header = :aec_blocks.to_header(key_block)
        height_miner_pk = :aec_headers.miner(key_header)
        height_beneficiary_pk = :aec_headers.beneficiary(key_header)
        delayed_height = height - delay

        beneficiaries_heights_miner =
          Map.put(beneficiaries_heights_miner, {height_beneficiary_pk, height}, height_miner_pk)

        if rem(height, @log_freq) == 0, do: IO.puts("Processed #{height} of #{total_gens}")

        miners_acc =
          state
          |> stream_miners_rewards(height)
          |> build_miners_acc(miners_acc, beneficiaries_heights_miner, height, delayed_height)

        {miners_acc, beneficiaries_heights_miner}
      end)

    mutations =
      Enum.map(miners, fn {miner_pk, total_reward} ->
        WriteMutation.new(Model.Miner, Model.miner(index: miner_pk, total_reward: total_reward))
      end)

    stat_mutation =
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.miners_count_key(), payload: map_size(miners))
      )

    State.commit(state, [stat_mutation | mutations])

    IO.puts("DONE")

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {total_gens, duration}}
  end

  defp build_miners_acc(
         miners_rewards,
         miners_acc,
         beneficiaries_heights_miner,
         height,
         delayed_height
       ) do
    Enum.reduce(miners_rewards, miners_acc, fn {beneficiary_pk, reward}, miners_acc ->
      miner_pk =
        Map.get(beneficiaries_heights_miner, {beneficiary_pk, delayed_height}) ||
          Map.get(beneficiaries_heights_miner, {beneficiary_pk, delayed_height - 1}) ||
          Map.get(beneficiaries_heights_miner, {beneficiary_pk, height})

      if miner_pk do
        Map.update(miners_acc, miner_pk, reward, &(&1 + reward))
      else
        beneficiary_pk = :aeser_api_encoder.encode(:account_pubkey, beneficiary_pk)
        IO.puts("PROBLEM: NO BENEFICIARY/MINER FOR HEIGHT #{height} - #{beneficiary_pk}")
        miners_acc
      end
    end)
  end

  defp stream_miners_rewards(state, height) do
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
  end
end
