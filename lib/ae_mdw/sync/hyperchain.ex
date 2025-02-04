defmodule AeMdw.Sync.Hyperchain do
  @moduledoc """
    This module is responsible for syncing of the hyperchain
  """
  alias AeMdw.Blocks
  alias AeMdw.Node.Db

  @type epoch() :: non_neg_integer()
  @type epoch_info() :: %{
          first: Blocks.height(),
          last: Blocks.height(),
          length: non_neg_integer(),
          seed: binary() | :undefined,
          epoch: epoch(),
          validators: list({Db.pubkey(), non_neg_integer()})
        }
  @type leader() :: Blocks.key_header()

  @spec hyperchain?() :: boolean()
  def hyperchain?() do
    case :aeu_env.user_config(["chain", "consensus", "0", "type"]) do
      {:ok, "hyperchain"} -> true
      _error -> false
    end
  end

  @spec connected_to_parent?() :: boolean()
  def connected_to_parent?() do
    :check_parent == :aec_parent_connector.request_top()
  end

  @spec epoch_info_at_height(Blocks.height()) :: {:ok, epoch_info()} | :error
  def epoch_info_at_height(height) do
    with {:ok, kb_hash} <- :aec_chain_state.get_key_block_hash_at_height(height),
         {_tx_env, _trees} = run_env <-
           :aetx_env.tx_env_and_trees_from_hash(:aetx_transaction, kb_hash),
         {:ok, epoch} <- :aec_chain_hc.epoch(run_env) do
      :aec_chain_hc.epoch_info_for_epoch(run_env, epoch)
    end
  end

  @spec leaders_for_epoch_at_height(Blocks.height()) :: [{leader(), Blocks.height()}]
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

    Enum.with_index(schedule, first)
  end

  @spec validators_at_height(Blocks.height()) :: [term()]
  def validators_at_height(height) do
    {:ok, %{validators: validators}} = epoch_info_at_height(height)
    validators
  end

  @spec get_delegates(Blocks.height(), Db.pubkey()) :: {:ok, map()} | {:error, term()} | :error
  def get_delegates(height, pubkey) do
    with {:ok, kb_hash} <- :aec_chain_state.get_key_block_hash_at_height(height),
         {tx_env, trees} <- :aetx_env.tx_env_and_trees_from_hash(:aetx_transaction, kb_hash),
         {:ok,
          {:tuple,
           {_ct, _address, _creation_height, _stake, _pending_stake, _stake_limit, _is_online,
            state}}} <-
           :aec_consensus_hc.call_consensus_contract_result(
             :staking,
             tx_env,
             trees,
             ~c"get_validator_state",
             [:aefa_fate_code.encode_arg({:address, pubkey})]
           ) do
      {:tuple,
       {_main_staking_ct, _unstake_deley, _pending_unstake_amount, _pending_unstake, _name,
        _description, _image_url, delegates, _shares}} = state

      delegates
      |> Enum.into(%{}, fn {{:address, pubkey}, stake} ->
        {pubkey, stake}
      end)
      |> then(&{:ok, &1})
    end
  end
end
