defmodule AeMdw.Db.EpochMutation do
  @moduledoc """
    Possibly put the new epochs for a hyperchain
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Hyperchain

  require Model

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
      put_new_epoch_info(state, height)
    else
      state
    end
  end

  defp new_epoch?(state, height) do
    not State.exists?(state, Model.EpochInfo, height)
  end

  defp put_new_epoch_info(state, height) do
    {:ok,
     %{
       first: first,
       last: last,
       length: length,
       seed: seed,
       epoch: epoch,
       validators: validators
     }} = Hyperchain.epoch_info_at_height(height)

    state =
      State.put(
        state,
        Model.EpochInfo,
        Model.epoch_info(
          index: epoch,
          first: first,
          last: last,
          length: length,
          seed: seed,
          validators: validators
        )
      )

    Enum.reduce(validators, state, fn {pubkey, stake}, state ->
      State.put(
        state,
        Model.Validator,
        Model.validator(index: {pubkey, epoch}, stake: stake)
      )
    end)
  end
end
