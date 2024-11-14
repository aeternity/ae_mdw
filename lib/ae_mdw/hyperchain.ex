defmodule AeMdw.Hyperchain do
  @moduledoc """
    Module for hyperchain related functions.
  """
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util.Encoding

  require Model

  @type epoch() :: non_neg_integer()
  @type epoch_info() :: %{
          first: Blocks.height(),
          last: Blocks.height(),
          length: non_neg_integer(),
          seed: binary() | :undefined,
          epoch: epoch(),
          validators: list({NodeDb.pubkey(), non_neg_integer()})
        }
  @typep leader() :: Blocks.key_header()

  @spec hyperchain?() :: boolean()
  def hyperchain?() do
    case :aeu_env.user_config(["chain", "consensus", "0", "type"]) do
      {:ok, "hyperchain"} -> true
      _ -> false
    end
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

  @spec leaders_for_epoch_at_height(Blocks.height()) :: [{Blocks.height(), leader()}]
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

  @spec validators_at_height(Blocks.height()) :: [term()]
  def validators_at_height(height) do
    {:ok, %{validators: validators}} = epoch_info_at_height(height)
    validators
  end

  @spec fetch_leaders(
          State.t(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) ::
          {Collection.cursor(), [leader()], Collection.cursor()}
  def fetch_leaders(state, pagination, scope, cursor) do
    cursor = deserialize_numeric_cursor(cursor)

    fn direction ->
      Collection.stream(state, Model.HyperchainLeaderAtHeight, direction, scope, cursor)
    end
    |> Collection.paginate(
      pagination,
      &render_leader(state, &1),
      &serialize_numeric_cursor/1
    )
  end

  @spec fetch_leader_by_height(State.t(), Blocks.height()) :: leader()
  def fetch_leader_by_height(state, height) do
    case State.get(state, Model.HyperchainLeaderAtHeight, height) do
      {:ok, Model.hyperchain_leader_at_height(index: ^height) = leader} ->
        {:ok, render_leader(state, leader)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: "height #{height}")}
    end
  end

  @spec fetch_epochs(
          State.t(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) ::
          {Collection.cursor(), [leader()], Collection.cursor()}
  def fetch_epochs(state, pagination, scope, cursor) do
    cursor = deserialize_numeric_cursor(cursor)

    fn direction ->
      Collection.stream(state, Model.EpochInfo, direction, scope, cursor)
    end
    |> Collection.paginate(
      pagination,
      &render_epoch_info(state, &1),
      &serialize_numeric_cursor/1
    )
  end

  def fetch_validator(state, validator_id) do
    # all_validator_entries =
    #   state
    #   |> Collection.stream(
    #     Model.Validator,
    #     Collection.generate_key_boundary({pubkey, Collection.integer()})
    #   )
    #   |> Enum.map(&State.fetch!(state, Model.Validator, &1))

    {:ok, pubkey} = Encoding.safe_decode(:account_pubkey, validator_id)

    current_height = State.height(state)
    {:ok, %{validators: validators}} = epoch_info_at_height(current_height)

    with {:ok, stake} <-
           Enum.find_value(validators, :not_found, fn {validator_pubkey, stake} ->
             if validator_pubkey == pubkey do
               {:ok, stake}
             end
           end) do
      {:ok,
       %{
         total_stakes: stake,
         delegates: get_delegates(current_height, pubkey)
       }}
    end
  end

  defp get_delegates(height, pubkey) do
    with {:ok, kb_hash} <- :aec_chain_state.get_key_block_hash_at_height(height),
         {tx_env, trees} <- :aetx_env.tx_env_and_trees_from_hash(:aetx_transaction, kb_hash) do
      {:ok,
       {:tuple,
        {_ct, _address, _creation_height, _stake, _pending_stake, _stake_limit, _is_online, state}}} =
        :aec_consensus_hc.call_consensus_contract_result(
          :staking,
          tx_env,
          trees,
          ~c"get_validator_state",
          [:aefa_fate_code.encode_arg({:address, pubkey})]
        )

      {:tuple,
       {_main_staking_ct, _unstake_deley, _pending_unstake_amount, _pending_unstake, _name,
        _description, _image_url, delegates, _shares}} = state

      Enum.into(delegates, %{}, fn {{:address, pubkey}, stake} ->
        {Encoding.encode_account(pubkey), stake}
      end)
    end
  end

  defp serialize_numeric_cursor(nil) do
    nil
  end

  defp serialize_numeric_cursor(height) do
    height
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp deserialize_numeric_cursor(nil) do
    nil
  end

  defp deserialize_numeric_cursor(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp render_leader(state, leader_height) when is_integer(leader_height) do
    state
    |> State.fetch!(Model.HyperchainLeaderAtHeight, leader_height)
    |> then(&render_leader(state, &1))
  end

  defp render_leader(_state, leader) do
    leader
    |> inspect()
  end

  defp render_epoch_info(state, epoch) when is_integer(epoch) do
    Model.epoch_info(
      index: ^epoch,
      first: first,
      last: last,
      length: length,
      seed: seed,
      validators: validators
    ) = State.fetch!(state, Model.EpochInfo, epoch)

    last_pin_height = first - 1

    {:ok, parent_block_hash} =
      :aec_chain_state.get_key_block_hash_at_height(last_pin_height)

    {:ok, last_block} =
      :aec_chain.get_key_block_by_height(last_pin_height)

    epoch_start_time = :aec_blocks.time_in_msecs(last_block)

    last_leader_height =
      state
      |> State.height()
      |> case do
        top when top > last ->
          last

        top when top < first ->
          last

        top ->
          top
      end

    Model.hyperchain_leader_at_height(leader: last_leader) =
      State.fetch!(state, Model.HyperchainLeaderAtHeight, last_leader_height)

    %{
      epoch: epoch,
      first: first,
      last: last,
      length: length,
      seed: seed,
      last_pin_height: last_pin_height,
      parent_block_hash: :aeapi.format_key_block_hash(parent_block_hash),
      last_leader: :aeapi.format_account_pubkey(last_leader),
      epoch_start_time: epoch_start_time,
      validators:
        Enum.map(validators, fn {pubkey, number} ->
          %{validator: Encoding.encode_account(pubkey), stake: number}
        end)
    }
  end
end
