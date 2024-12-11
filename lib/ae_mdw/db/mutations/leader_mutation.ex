defmodule AeMdw.Db.LeaderMutation do
  @moduledoc """
    Possibly put the new leaders for a hyperchain
  """

  # alias AeMdw.Collection
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.Hyperchain

  require Model
  require Logger

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height) do
    %__MODULE__{
      height: height
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    if new_epoch?(state, height) do
      put_new_leaders(state, height)
    else
      state
    end
  end

  defp new_epoch?(state, height) do
    not State.exists?(state, Model.HyperchainLeaderAtHeight, height)
  end

  defp put_new_leaders(state, height) do
    height
    |> Hyperchain.epoch_info_at_height()
    |> case do
      {:ok, %{epoch: epoch, first: _start_height}} ->
        state =
          height
          |> Hyperchain.leaders_for_epoch_at_height()
          |> Enum.reduce(state, fn {height, leader}, state ->
            state
            |> State.put(
              Model.HyperchainLeaderAtHeight,
              Model.hyperchain_leader_at_height(index: height, leader: leader)
            )
            |> State.put(
              Model.Validator,
              Model.validator(index: {leader, epoch})
            )
            |> State.put(
              Model.RevValidator,
              Model.rev_validator(index: {epoch, leader})
            )
          end)

        state
        # |> Collection.stream(
        #   Model.RevValidator,
        #   :backward,
        #   Collection.generate_key_boundary({epoch, Collection.binary()}),
        #   nil
        # )

        # |> Enum.reduce(state, fn {^epoch, leader}, state ->
        #   put_delegates(state, start_height, epoch, leader)
        # end)
    end
  end

  def put_delegates(state, start_height, epoch, leader) do
    start_height
    |> Hyperchain.get_delegates(leader)
    |> case do
      {:ok, delegates} ->
        Enum.reduce(delegates, state, fn {delegate, stake}, acc_state ->
          State.put(
            acc_state,
            Model.Delegate,
            Model.delegate(index: {leader, epoch, delegate}, stake: stake)
          )
        end)

      :error ->
        Logger.error(
          "Error fetching delegates for leader #{inspect(leader)} at height #{start_height} in epoch #{epoch}"
        )

        state
    end
  end
end
