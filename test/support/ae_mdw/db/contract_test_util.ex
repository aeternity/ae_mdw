defmodule Support.AeMdw.Db.ContractTestUtil do
  @moduledoc """
  Contract testing helper functions.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db

  require Model
  require Ex2ms

  @spec aex9_presence_txi_list(Db.pubkey(), Db.pubkey()) :: [AeMdw.Txs.txi()]
  def aex9_presence_txi_list(contract_pk, account_pk) do
    boundary = {
      {account_pk, -1, contract_pk},
      {account_pk, nil, contract_pk}
    }

    Model.Aex9AccountPresence
    |> Collection.stream(:forward, boundary, nil)
    |> Enum.flat_map(fn
      {^account_pk, txi, ^contract_pk} -> [txi]
      _other_ct -> []
    end)
  end

  @spec aex9_delete_presence(Db.pubkey(), Db.pubkey()) :: :ok
  def aex9_delete_presence(contract_pk, account_pk) do
    contract_pk
    |> aex9_presence_txi_list(account_pk)
    |> Enum.each(fn txi ->
      Database.dirty_delete(Model.Aex9AccountPresence, {account_pk, txi, contract_pk})
      Database.dirty_delete(Model.IdxAex9AccountPresence, {txi, account_pk, contract_pk})
    end)
  end
end
