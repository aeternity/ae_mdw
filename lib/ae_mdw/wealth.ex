defmodule AeMdw.Wealth do
  @moduledoc """
  Main wealth module.
  """

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.WealthRank

  require Model

  @spec fetch_balances(State.t()) :: [tuple()]
  def fetch_balances(state) do
    state
    |> Collection.stream(Model.BalanceAccount, :backward, nil, {nil, nil})
    |> Stream.map(fn {balance, pubkey} -> %{balance: balance, account: encode_account(pubkey)} end)
    |> Enum.take(WealthRank.rank_size_config())
  end
end
