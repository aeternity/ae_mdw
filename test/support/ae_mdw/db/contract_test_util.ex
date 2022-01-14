defmodule Support.AeMdw.Db.ContractTestUtil do
  @moduledoc """
  Contract testing helper functions.
  """

  alias AeMdw.Node.Db
  alias AeMdw.Db.Model

  require Model
  require Ex2ms

  @spec aex9_delete_presence(Db.pubkey(), Db.pubkey()) :: :ok
  def aex9_delete_presence(contract_pk, account_pk) do
    presence_mspec =
      Ex2ms.fun do
        Model.aex9_account_presence(index: {^account_pk, txi, ^contract_pk}) ->
          {^account_pk, txi, ^contract_pk}
      end

    Model.Aex9AccountPresence
    |> :mnesia.select(presence_mspec)
    |> Enum.each(fn {account_pk, txi, contract_pk} ->
      :mnesia.delete(Model.Aex9AccountPresence, {account_pk, txi, contract_pk}, :write)
      :mnesia.delete(Model.IdxAex9AccountPresence, {txi, account_pk, contract_pk}, :write)
    end)
  end
end
