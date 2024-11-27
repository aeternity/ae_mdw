defmodule AeMdw.Hyperchain do
  @moduledoc """
    Module for hyperchain related functions.
  """
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util.Encoding
  alias AeMdw.Sync.Hyperchain

  require Model

  @type validator() :: %{
          total_stakes: non_neg_integer(),
          delegates: %{Db.pubkey() => non_neg_integer()},
          rewards_earned: non_neg_integer(),
          pinning_history: %{Blocks.height() => non_neg_integer()},
          validator: Db.pubkey(),
          epoch: Blocks.height()
        }

  @spec fetch_epochs(
          State.t(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) ::
          {:ok, {Collection.cursor(), [Hyperchain.leader()], Collection.cursor()}}
  def fetch_epochs(state, pagination, scope, cursor) do
    with {:ok, scope} <- deserialize_epoch_scope(scope) do
      cursor = deserialize_numeric_cursor(cursor)

      fn direction ->
        Collection.stream(state, Model.EpochInfo, direction, scope, cursor)
      end
      |> Collection.paginate(
        pagination,
        &render_epoch_info(state, &1),
        &serialize_numeric_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_leaders_schedule(
          State.t(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) ::
          {:ok, {Collection.cursor(), [Hyperchain.leader()], Collection.cursor()}}
  def fetch_leaders_schedule(state, pagination, scope, cursor) do
    with {:ok, scope} <- deserialize_leaders_scope(scope) do
      cursor = deserialize_numeric_cursor(cursor)

      fn direction ->
        Collection.stream(state, Model.HyperchainLeaderAtHeight, direction, scope, cursor)
      end
      |> Collection.paginate(
        pagination,
        &render_leader(state, &1),
        &serialize_numeric_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_leaders_schedule_at_height(State.t(), Blocks.height()) :: Hyperchain.leader()
  def fetch_leaders_schedule_at_height(state, height) do
    case State.get(state, Model.HyperchainLeaderAtHeight, height) do
      {:ok, Model.hyperchain_leader_at_height(index: ^height) = leader} ->
        {:ok, render_leader(state, leader)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: "height #{height}")}
    end
  end

  @spec fetch_validators(
          State.t(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) ::
          {:ok, {Collection.cursor(), [validator()], Collection.cursor()}}
  def fetch_validators(state, pagination, scope, cursor) do
    with {:ok, scope} <- deserialize_validator_scope(scope) do
      cursor = deserialize_validator_cursor(cursor)

      fn direction ->
        Collection.stream(state, Model.RevValidator, direction, scope, cursor)
      end
      |> Collection.paginate(
        pagination,
        &render_validator(state, &1, State.height(state)),
        &serialize_validator_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_validator(State.t(), term()) :: {:ok, validator()}
  def fetch_validator(state, validator_id) do
    with {:ok, pubkey} <- Encoding.safe_decode(:account_pubkey, validator_id),
         current_height <- State.height(state),
         {:ok, %{epoch: epoch}} <- Hyperchain.epoch_info_at_height(current_height),
         {:ok, validator} <- State.get(state, Model.Validator, {pubkey, epoch}) do
      {:ok, render_validator(state, validator, current_height)}
    end
  end

  defp render_validator(
         state,
         {epoch, pubkey},
         current_height
       ) do
    validator = State.fetch!(state, Model.Validator, {pubkey, epoch})
    render_validator(state, validator, current_height)
  end

  defp render_validator(
         state,
         Model.validator(index: {pubkey, epoch}, stake: stake),
         current_height
       ) do
    total_rewards =
      case State.get(state, Model.Miner, pubkey) do
        {:ok, Model.miner(total_reward: total_reward)} ->
          total_reward

        :not_found ->
          0
      end

    pinning_history =
      state
      |> Collection.stream(
        Model.LeaderPinInfo,
        Collection.generate_key_boundary({pubkey, Collection.integer()})
      )
      |> Enum.into(%{}, fn key ->
        Model.leader_pin_info(index: {^pubkey, epoch}, reward: reward) =
          State.fetch!(state, Model.LeaderPinInfo, key)

        {epoch, reward}
      end)

    %{
      total_stakes: stake,
      delegates: get_delegates(current_height, pubkey),
      rewards_earned: total_rewards,
      pinning_history: pinning_history,
      validator: Encoding.encode_account(pubkey),
      epoch: epoch
    }
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
          asd =
            State.fetch!(state, Model.HyperchainLeaderAtHeight, top)
            |> then(fn Model.hyperchain_leader_at_height(leader: leader) ->
              Encoding.encode_account(leader)
            end)

          wasd =
            State.fetch!(state, Model.HyperchainLeaderAtHeight, last)
            |> then(fn Model.hyperchain_leader_at_height(leader: leader) ->
              Encoding.encode_account(leader)
            end)

          IO.inspect({asd, wasd}, label: "top, last")
          top
      end
      |> tap(&IO.inspect({first, last, &1}, label: "first, last, top"))

    Model.hyperchain_leader_at_height(leader: last_leader) =
      State.fetch!(state, Model.HyperchainLeaderAtHeight, last_leader_height)

    %{
      epoch: epoch,
      first: first,
      last: last,
      length: length,
      seed: seed,
      last_pin_height: last_pin_height,
      parent_block_hash: Encoding.encode_block(:key, parent_block_hash),
      last_leader: Encoding.encode_account(last_leader),
      epoch_start_time: epoch_start_time,
      validators:
        Enum.map(validators, fn {pubkey, number} ->
          %{validator: Encoding.encode_account(pubkey), stake: number}
        end)
    }
  end

  defp deserialize_leaders_scope(scope) do
    case scope do
      nil ->
        {:ok, nil}

      {:gen, first_gen..last_gen//_step} ->
        {:ok, {first_gen, last_gen}}

      {:epoch, first_epoch..last_epoch//_step} ->
        with {:ok, epoch_length} = Node.epoch_length(last_epoch),
             {:ok, first_gen} <- Node.epoch_start_height(first_epoch),
             {:ok, last_gen} <- Node.epoch_start_height(last_epoch) do
          {:ok, {first_gen, last_gen + epoch_length - 1}}
        else
          {:error, error} ->
            {:error, ErrInput.Scope.exception(value: error)}
        end
    end
  end

  defp deserialize_validator_scope(scope) do
    case scope do
      nil ->
        {:ok, nil}

      {:epoch, first_epoch..last_epoch//_step} ->
        {:ok,
         Collection.generate_key_boundary(
           {Collection.gen_range(first_epoch, last_epoch), Collection.binary()}
         )}

      _otherwise ->
        {:error, ErrInput.Scope.exception(value: "invalid epoch scope")}
    end
  end

  defp deserialize_epoch_scope(scope) do
    case scope do
      nil ->
        {:ok, nil}

      {:epoch, first_epoch..last_epoch//_step} ->
        {:ok, {first_epoch, last_epoch}}

      _otherwise ->
        {:error, ErrInput.Scope.exception(value: "invalid epoch scope")}
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

  defp deserialize_validator_cursor(nil) do
    nil
  end

  defp deserialize_validator_cursor(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp serialize_validator_cursor(nil) do
    nil
  end

  defp serialize_validator_cursor({_pubkey, _epoch} = rev_validator_index) do
    rev_validator_index
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end
end
