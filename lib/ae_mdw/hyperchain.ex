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
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util.Encoding
  alias AeMdw.Sync.Hyperchain

  require Model

  @type validator() :: %{
          total_stakes: non_neg_integer(),
          delegates: non_neg_integer(),
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

  @spec fetch_epoch_top(State.t()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_epoch_top(state) do
    current_height = State.height(state)

    with {:ok, %{epoch: epoch}} <- Hyperchain.epoch_info_at_height(current_height) do
      {:ok, render_epoch_info(state, epoch)}
    else
      error when error in [:not_found, :error] ->
        {:error, ErrInput.NotFound.exception(value: "epoch at height #{current_height}")}
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
          {:ok, {Collection.cursor(), [validator()], Collection.cursor()}} | {:error, term()}
  def fetch_validators(state, pagination, scope, cursor) do
    with {:ok, scope} <- deserialize_validator_scope(scope) do
      cursor = deserialize_validator_cursor(cursor)

      fn direction ->
        Collection.stream(state, Model.RevValidator, direction, scope, cursor)
      end
      |> Collection.paginate(
        pagination,
        &render_validator(state, &1),
        &serialize_validator_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_validators_top(
          State.t(),
          Collection.pagination(),
          Collection.cursor()
        ) ::
          {:ok, {Collection.cursor(), [validator()], Collection.cursor()}} | {:error, term()}
  def fetch_validators_top(state, pagination, cursor) do
    with current_height <- State.height(state),
         {:ok, %{epoch: epoch}} <- Hyperchain.epoch_info_at_height(current_height) do
      scope = {:epoch, epoch..epoch}
      fetch_validators(state, pagination, scope, cursor)
    end
  end

  @spec fetch_validator(State.t(), term()) :: {:ok, validator()}
  def fetch_validator(state, validator_id) do
    with {:ok, pubkey} <- Encoding.safe_decode(:account_pubkey, validator_id),
         current_height <- State.height(state),
         {:ok, %{epoch: epoch}} <- Hyperchain.epoch_info_at_height(current_height),
         {:ok, validator} <- State.get(state, Model.Validator, {pubkey, epoch}) do
      {:ok, render_validator(state, validator)}
    end
  end

  @spec fetch_delegates(
          State.t(),
          Db.pubkey(),
          Collection.pagination(),
          Collection.range(),
          Collection.cursor()
        ) :: {:ok, {Collection.cursor(), [Db.pubkey()], Collection.cursor()}}
  def fetch_delegates(state, validator_id, pagination, scope, cursor) do
    with {:ok, pubkey} <- Encoding.safe_decode(:account_pubkey, validator_id),
         {:ok, scope} <- deserialize_validator_delegates_scope(scope) do
      cursor =
        deserialize_validator_delegates_cursor(cursor)

      scope =
        case scope do
          nil ->
            Collection.generate_key_boundary({pubkey, Collection.integer(), Collection.binary()})

          {first_epoch, last_epoch} ->
            Collection.generate_key_boundary(
              {pubkey, Collection.gen_range(first_epoch, last_epoch), Collection.binary()}
            )
        end

      fn direction ->
        Collection.stream(
          state,
          Model.Delegate,
          direction,
          scope,
          cursor
        )
      end
      |> Collection.paginate(
        pagination,
        &render_validator_delegate(state, &1),
        &serialize_validator_delegates_cursor/1
      )
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_delegates_top(
          State.t(),
          Db.pubkey(),
          Collection.pagination(),
          Collection.cursor()
        ) :: {:ok, {Collection.cursor(), [Db.pubkey()], Collection.cursor()}}

  def fetch_delegates_top(state, validator_id, pagination, cursor) do
    with current_height <- State.height(state),
         {:ok, %{epoch: epoch}} <- Hyperchain.epoch_info_at_height(current_height) do
      scope = {:epoch, epoch..epoch}
      fetch_delegates(state, validator_id, pagination, scope, cursor)
    end
  end

  defp render_validator(
         state,
         {epoch, pubkey}
       ) do
    validator = State.fetch!(state, Model.Validator, {pubkey, epoch})
    render_validator(state, validator)
  end

  defp render_validator(
         state,
         Model.validator(index: {pubkey, epoch}, stake: stake)
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
      delegates: get_delegates(state, epoch, pubkey),
      rewards_earned: total_rewards,
      pinning_history: pinning_history,
      validator: Encoding.encode_account(pubkey),
      epoch: epoch
    }
  end

  defp get_delegates(state, epoch, pubkey) do
    state
    |> Collection.stream(
      Model.Delegate,
      :backward,
      Collection.generate_key_boundary({pubkey, epoch, Collection.binary()}),
      nil
    )
    |> Enum.count()
  end

  defp render_leader(state, leader_height) when is_integer(leader_height) do
    state
    |> State.fetch!(Model.HyperchainLeaderAtHeight, leader_height)
    |> then(&render_leader(state, &1))
  end

  defp render_leader(_state, Model.hyperchain_leader_at_height(index: height, leader: leader)) do
    %{height: height, leader: Encoding.encode_account(leader)}
  end

  defp render_epoch_info(state, epoch_index) when is_integer(epoch_index) do
    epoch =
      Model.epoch_info(index: ^epoch_index) = State.fetch!(state, Model.EpochInfo, epoch_index)

    render_epoch_info(state, epoch)
  end

  defp render_epoch_info(
         state,
         Model.epoch_info(index: epoch, first: first, last: last, length: length, seed: seed)
       ) do
    last_pin_height = first - 1

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

    validators =
      state
      |> Collection.stream(
        Model.RevValidator,
        :backward,
        Collection.generate_key_boundary({epoch, Collection.binary()}),
        nil
      )
      |> Enum.map(fn {^epoch, pubkey} ->
        Model.validator(stake: stake) =
          State.fetch!(state, Model.Validator, {pubkey, epoch})

        %{validator: Encoding.encode_account(pubkey), stake: stake}
      end)

    %{
      epoch: epoch,
      first: first,
      last: last,
      length: length,
      seed: seed,
      last_pin_height: last_pin_height,
      last_leader: Encoding.encode_account(last_leader),
      epoch_start_time: epoch_start_time,
      validators: validators
    }
  end

  defp render_validator_delegate(state, {leader, epoch, delegate}) do
    Model.delegate(index: {^leader, ^epoch, ^delegate}, stake: stake) =
      State.fetch!(state, Model.Delegate, {leader, epoch, delegate})

    %{
      delegate: Encoding.encode_account(delegate),
      stake: stake,
      epoch: epoch,
      validator: Encoding.encode_account(leader)
    }
  end

  defp deserialize_leaders_scope(scope) do
    case scope do
      nil ->
        {:ok, nil}

      {:gen, first_gen..last_gen//_step} ->
        {:ok, {first_gen, last_gen}}

      {:epoch, first_epoch..last_epoch//_step} ->
        with {:ok, epoch_length} <- Node.epoch_length(last_epoch),
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

  defp deserialize_validator_delegates_scope(scope) do
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

  defp serialize_validator_delegates_cursor(nil) do
    nil
  end

  defp serialize_validator_delegates_cursor({_pubkey, _epoch, _delegate} = delegate_index) do
    delegate_index
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp deserialize_validator_delegates_cursor(nil) do
    nil
  end

  defp deserialize_validator_delegates_cursor(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end
