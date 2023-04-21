defmodule AeMdw.Wealth do
  @moduledoc """
  Main wealth module.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  require Model

  @rank_size 100

  @spec fetch_balances() :: [tuple()]
  def fetch_balances() do
    AsyncStore.instance()
    |> State.new()
    |> Collection.stream(Model.BalanceAccount, :backward, nil, {nil, nil})
    |> Enum.map(fn {balance, pubkey} -> %{balance: balance, account: encode_account(pubkey)} end)
    |> Enum.take(@rank_size)
  end
end
