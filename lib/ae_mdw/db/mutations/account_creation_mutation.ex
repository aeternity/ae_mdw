defmodule AeMdw.Db.AccountCreationMutation do
  @moduledoc """
    Mark account creation time
  """

  alias AeMdw.Accounts
  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  @derive AeMdw.Db.Mutation
  defstruct [:account_pk, :time, :height]

  @opaque t() :: %__MODULE__{
            account_pk: Db.pubkey(),
            time: Blocks.time(),
            height: Blocks.height()
          }

  @spec new(Db.pubkey(), Blocks.time(), Blocks.height()) :: t()
  def new(account_pk, time, height) do
    %__MODULE__{account_pk: account_pk, time: time, height: height}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          account_pk: account_pk,
          time: time,
          height: height
        },
        state
      ) do
    Accounts.maybe_increase_creation_statistics(state, account_pk, time, height)
  end
end
