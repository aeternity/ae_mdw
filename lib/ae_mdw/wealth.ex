defmodule AeMdw.Wealth do
  @moduledoc """
  Main wealth module.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.WealthRank

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  require Model

  @spec fetch_balances(AsyncStore.t()) :: [tuple()]
  def fetch_balances(%AsyncStore{} = async_store) do
    async_store
    |> State.new()
    |> Collection.stream(Model.BalanceAccount, :backward, nil, {nil, nil})
    |> Enum.map(fn {balance, pubkey} -> %{balance: balance, account: encode_account(pubkey)} end)
    |> Enum.take(WealthRank.rank_size_config())
  end
end
