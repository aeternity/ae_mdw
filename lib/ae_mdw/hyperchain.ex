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
    with {:ok, epoch} <- :aec_chain_hc.epoch(height) do
      :aec_chain_hc.epoch_info_for_epoch(height, epoch)
    end
  end

  @spec leaders_for_epoch_at_height(Blocks.height()) :: [{Blocks.height(), leader()}]
  def leaders_for_epoch_at_height(height) do
    {:ok, epoch} = :aec_chain_hc.epoch(height)

    {:ok, %{seed: seed, validators: validators, length: length, first: first} = _epoch_info} =
      :aec_chain_hc.epoch_info_for_epoch(height, epoch)

    {:ok, seed} =
      case seed do
        :undefined ->
          :aec_consensus_hc.get_entropy_hash(epoch)

        otherwise ->
          {:ok, otherwise}
      end

    {:ok, schedule} = :aec_chain_hc.validator_schedule(height, seed, validators, length)

    first
    |> Stream.iterate(fn x -> x + 1 end)
    |> Enum.zip(schedule)
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

    %{
      epoch: epoch,
      first: first,
      last: last,
      length: length,
      seed: seed,
      validators:
        Enum.map(validators, fn {pubkey, number} -> {Encoding.encode_account(pubkey), number} end)
    }
  end
end
