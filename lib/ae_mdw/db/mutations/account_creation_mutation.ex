defmodule AeMdw.Db.AccountCreationMutation do
  @moduledoc """
    Mark account creation time
  """

  alias AeMdw.Accounts
  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  @derive AeMdw.Db.Mutation
  defstruct [:account_pk, :time]

  @opaque t() :: %__MODULE__{
            account_pk: Db.pubkey(),
            time: Blocks.time()
          }

  @spec new(Db.pubkey(), Blocks.time()) :: t()
  def new(account_pk, time) do
    %__MODULE__{account_pk: account_pk, time: time}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          account_pk: account_pk,
          time: time
        },
        state
      ) do
    Accounts.maybe_increase_creation_statistics(state, account_pk, time)
  end
end
