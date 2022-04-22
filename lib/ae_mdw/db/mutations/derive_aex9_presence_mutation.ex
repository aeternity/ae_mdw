defmodule AeMdw.Db.DeriveAex9PresenceMutation do
  @moduledoc """
  Stores the derived aex9 balances for a contract.
  """

  alias AeMdw.Aex9
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :create_txi, :balances]

  @typep aex9_balance() :: {Db.pubkey(), Aex9.amount()}

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            create_txi: Txs.txi(),
            balances: [aex9_balance()]
          }

  @spec new(Db.pubkey(), Txs.txi(), [aex9_balance()]) :: t()
  def new(contract_pk, create_txi, balances) do
    %__MODULE__{
      contract_pk: contract_pk,
      create_txi: create_txi,
      balances: balances
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          create_txi: create_txi,
          balances: balances
        },
        state
      ) do
    Enum.reduce(balances, state, fn {account_pk, amount}, state ->
      m_balance =
        Model.aex9_balance(
          index: {contract_pk, account_pk},
          amount: amount
        )

      state
      |> Contract.aex9_write_presence(contract_pk, create_txi, account_pk)
      |> State.put(Model.Aex9Balance, m_balance)
    end)
  end
end
