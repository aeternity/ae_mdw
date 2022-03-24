defmodule AeMdw.Node.AeTxFixtures do
  @moduledoc false

  alias AeMdw.Node.Db
  alias AeMdw.Names

  @spec new_aens_update_tx(Db.pubkey(), Names.plain_name(), non_neg_integer()) :: tuple()
  def new_aens_update_tx(owner_pk, plain_name, name_ttl) do
    account_id = :aeser_id.create(:account, owner_pk)
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    {:ok, aetx} =
      :aens_update_tx.new(%{
        account_id: account_id,
        nonce: 1,
        name_id: :aeser_id.create(:name, name_hash),
        name_ttl: name_ttl,
        pointers: [:aens_pointer.new("account_pubkey", account_id)],
        client_ttl: 0,
        fee: 17_780_000_000_000
      })

    {_mod, tx} = :aetx.specialize_type(aetx)
    tx
  end
end
