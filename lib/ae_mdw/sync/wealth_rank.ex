defmodule AeMdw.Sync.WealthRank do
  @moduledoc """
  Wallet balance ranking.
  """

  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.UpdateBalanceAccountMutation

  require Model

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep balances :: [{pubkey(), integer()}]
  @opaque key :: {integer, pubkey()}

  @spec rank_size_config :: integer()
  def rank_size_config do
    with nil <- :persistent_term.get({__MODULE__, :rank_size}, nil) do
      rank_size = Application.fetch_env!(:ae_mdw, :wealth_rank_size)
      :persistent_term.put({__MODULE__, :rank_size}, rank_size)
      rank_size
    end
  end

  @spec update_balances(State.t(), balances()) :: State.t()
  def update_balances(state, balances) do
    Enum.reduce(balances, state, fn {account_pk, balance}, acc ->
      account_pk
      |> UpdateBalanceAccountMutation.new(balance)
      |> Mutation.execute(acc)
    end)
  end
end
