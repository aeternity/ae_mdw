defmodule Support.AeMdw.Db.ContractTestUtil do
  @moduledoc """
  Contract testing helper functions.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model
  require Ex2ms

  @spec aex9_presence_txi_list(State.t(), Db.pubkey(), Db.pubkey()) :: [AeMdw.Txs.txi()]
  def aex9_presence_txi_list(state, contract_pk, account_pk) do
    boundary = {
      {account_pk, -1, contract_pk},
      {account_pk, nil, contract_pk}
    }

    state
    |> Collection.stream(Model.Aex9AccountPresence, :forward, boundary, nil)
    |> Enum.flat_map(fn
      {^account_pk, txi, ^contract_pk} -> [txi]
      _other_ct -> []
    end)
  end

  @spec aex9_delete_presence(State.t(), Db.pubkey(), Db.pubkey()) :: :ok
  def aex9_delete_presence(state, contract_pk, account_pk) do
    state
    |> aex9_presence_txi_list(contract_pk, account_pk)
    |> Enum.each(fn txi ->
      Database.dirty_delete(Model.Aex9AccountPresence, {account_pk, txi, contract_pk})
      Database.dirty_delete(Model.IdxAex9AccountPresence, {txi, account_pk, contract_pk})
    end)
  end

  @spec encode_account(Db.pubkey()) :: String.t()
  def encode_account(account_pk), do: :aeser_api_encoder.encode(:account_pubkey, account_pk)
end
