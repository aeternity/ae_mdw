defmodule AeMdw.Hyperchain do
  @moduledoc """
    Module for hyperchain related functions.
  """

  def leaders_for_epoch_at_height(height) do
    {:ok, kb_hash} = :aec_chain_state.get_key_block_hash_at_height(height)
    {_tx_env, _trees} = run_env = :aetx_env.tx_env_and_trees_from_hash(:aetx_transaction, kb_hash)
    {:ok, epoch} = :aec_chain_hc.epoch(run_env)

    {:ok, %{seed: seed, validators: validators, length: length, first: first} = _epoch_info} =
      :aec_chain_hc.epoch_info_for_epoch(run_env, epoch)

    {:ok, seed} =
      case seed do
        :undefined ->
          :aec_consensus_hc.get_entropy_hash(epoch)

        otherwise ->
          {:ok, otherwise}
      end

    {:ok, schedule} = :aec_chain_hc.validator_schedule(run_env, seed, validators, length)

    first
    |> Stream.iterate(fn x -> x + 1 end)
    |> Enum.zip(schedule)
  end
end
