defmodule AeMdw.Migrations.Aex9BalanceAccount do
  @moduledoc """
  Indexes aex9 balance account sorting by amount.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(
        Model.Aex9EventBalance,
        :forward,
        nil,
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.Aex9EventBalance, &1))
      |> Enum.map(fn Model.aex9_event_balance(
                       index: {contract_pk, account_pk},
                       txi: txi,
                       log_idx: log_idx,
                       amount: amount
                     ) ->
        m_bal_acc =
          Model.aex9_balance_account(
            index: {contract_pk, amount, account_pk},
            txi: txi,
            log_idx: log_idx
          )

        WriteMutation.new(Model.Aex9BalanceAccount, m_bal_acc)
      end)

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
