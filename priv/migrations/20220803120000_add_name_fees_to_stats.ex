defmodule AeMdw.Migrations.AddNameFeesToStats do
  @moduledoc """
  Add auctions_burned and auctions_locked attribute to delta and total stats.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @log_freq 1_000

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    total_gens =
      case state |> Collection.stream(Model.DeltaStat, :backward, nil, nil) |> Enum.take(1) do
        [total_gens] -> total_gens
        [] -> 0
      end

    {mutations, _last_burned_locked} =
      state
      |> Collection.stream(Model.DeltaStat, nil)
      |> Stream.map(fn height ->
        {State.fetch!(state, Model.DeltaStat, height),
         State.fetch!(state, Model.TotalStat, height + 1)}
      end)
      |> Enum.flat_map_reduce({0, 0}, fn {old_delta_stat, old_total_stat},
                                         {prev_burned, prev_locked} ->
        delta_stat = Model.delta_stat(index: height) = transform_delta_stat(old_delta_stat)
        total_stat = transform_total_stat(old_total_stat)

        delta_burned = height_int_amount(state, height, :lock_name)
        delta_spend = height_int_amount(state, height, :spend_name)
        delta_refund = height_int_amount(state, height, :refund_name)
        delta_locked = delta_spend - delta_refund
        new_total_burned = prev_burned + delta_burned
        new_total_locked = prev_locked + delta_locked

        new_delta_stat =
          Model.delta_stat(delta_stat,
            burned_in_auctions: delta_burned,
            locked_in_auctions: delta_locked
          )

        new_total_stat =
          Model.total_stat(total_stat,
            burned_in_auctions: new_total_burned,
            locked_in_auctions: new_total_locked
          )

        if rem(height, @log_freq) == 0, do: IO.puts("Processed #{height} of #{total_gens}")

        {
          [
            WriteMutation.new(Model.DeltaStat, new_delta_stat),
            WriteMutation.new(Model.TotalStat, new_total_stat)
          ],
          {new_total_burned, new_total_locked}
        }
      end)

    _state = State.commit(state, mutations)

    {:ok, div(length(mutations), 2)}
  end

  defp transform_delta_stat(
         {:delta_stat, height, auctions_started, names_activated, names_expired, names_revoked,
          oracles_registered, oracles_expired, contracts_created, block_reward, dev_reward}
       ) do
    Model.delta_stat(
      index: height,
      auctions_started: auctions_started,
      names_activated: names_activated,
      names_expired: names_expired,
      names_revoked: names_revoked,
      oracles_registered: oracles_registered,
      oracles_expired: oracles_expired,
      contracts_created: contracts_created,
      block_reward: block_reward,
      dev_reward: dev_reward
    )
  end

  defp transform_total_stat(
         {:total_stat, height, block_reward, dev_reward, total_supply, active_auctions,
          active_names, inactive_names, active_oracles, inactive_oracles, contracts}
       ) do
    Model.total_stat(
      index: height,
      block_reward: block_reward,
      dev_reward: dev_reward,
      total_supply: total_supply,
      active_auctions: active_auctions,
      active_names: active_names,
      inactive_names: inactive_names,
      active_oracles: active_oracles,
      inactive_oracles: inactive_oracles,
      contracts: contracts
    )
  end

  defp height_int_amount(state, height, kind) do
    kind_str = "fee_#{kind}"

    state
    |> Collection.stream(Model.KindIntTransferTx, {kind_str, {height, -1}, Util.min_bin(), nil})
    |> Stream.take_while(&match?({^kind_str, {^height, _mbi}, _address, _ref_txi}, &1))
    |> Stream.map(fn {kind_str, block_index, address, ref_txi} ->
      {block_index, kind_str, address, ref_txi}
    end)
    |> Stream.map(&State.fetch!(state, Model.IntTransferTx, &1))
    |> Enum.reduce(0, fn Model.int_transfer_tx(amount: amount), amount_acc ->
      amount_acc + amount
    end)
  end
end
