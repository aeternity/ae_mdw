defmodule AeMdw.Db.UpdateBalanceAccountMutation do
  @moduledoc """
    Update the balance of an account.
  """

  alias AeMdw.Stats
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:account_pk, :balance]

  @typep account_balance() :: non_neg_integer()
  @opaque t() :: %__MODULE__{
            account_pk: Db.pubkey(),
            balance: account_balance()
          }

  @spec new(Db.pubkey(), account_balance()) :: t()
  def new(account_pk, balance) do
    %__MODULE__{
      account_pk: account_pk,
      balance: balance
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          account_pk: account_pk,
          balance: balance
        },
        state
      ) do
    state
    |> get_balance(account_pk)
    |> case do
      old_balance when old_balance != nil ->
        state
        |> State.delete(Model.BalanceAccount, {old_balance, account_pk})
        |> State.delete(Model.AccountBalance, account_pk)
        |> insert(account_pk, balance, old_balance)

      _balance ->
        insert(state, account_pk, balance, 0)
    end
  end

  defp insert(state, pubkey, balance, old_balance) do
    balance_account_record = Model.balance_account(index: {balance, pubkey})
    account_balance_record = Model.account_balance(index: pubkey, balance: balance)

    state
    |> State.put(Model.BalanceAccount, balance_account_record)
    |> State.put(Model.AccountBalance, account_balance_record)
    |> then(fn state ->
      cond do
        old_balance > 0 and balance == 0 ->
          update_holders_stat(state, -1)

        old_balance == 0 and balance > 0 ->
          update_holders_stat(state, 1)

        true ->
          state
      end
    end)
  end

  defp get_balance(state, pubkey) do
    state
    |> State.get(Model.AccountBalance, pubkey)
    |> case do
      {:ok, Model.account_balance(balance: balance)} -> balance
      :not_found -> nil
    end
  end

  defp update_holders_stat(state, delta) do
    state
    |> State.get(Model.Stat, Stats.holders_count_key())
    |> case do
      {:ok, Model.stat(payload: holders_count)} ->
        state
        |> State.put(
          Model.Stat,
          Model.stat(index: Stats.holders_count_key(), payload: holders_count + delta)
        )

      :not_found ->
        state
        |> State.put(
          Model.Stat,
          Model.stat(index: Stats.holders_count_key(), payload: delta)
        )
    end
  end
end
