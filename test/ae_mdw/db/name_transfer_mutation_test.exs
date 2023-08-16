defmodule AeMdw.Db.NameTransferMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.NameTransferMutation

  require Model

  test "transfers an active name" do
    plain_name = "transfer.test"
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    active_height = System.unique_integer([:positive])
    transfer_height = active_height + 1
    transfer_txi_idx = {System.unique_integer([:positive]), -1}
    expire = active_height + 2
    owner_pk = TS.address(0)
    recipient_pk = TS.address(1)

    active_name =
      Model.name(
        index: plain_name,
        active: active_height,
        expire: expire,
        owner: owner_pk
      )

    {:name_transfer_tx, tx} =
      %{
        account_id: :aeser_id.create(:name, name_hash),
        nonce: 111,
        name_id: :aeser_id.create(:account, owner_pk),
        recipient_id: :aeser_id.create(:account, recipient_pk),
        fee: 1_111,
        ttl: 11_111
      }
      |> :aens_transfer_tx.new()
      |> then(fn {:ok, tx} -> :aetx.specialize_type(tx) end)

    state1 =
      empty_store()
      |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
      |> State.new()
      |> Name.put_active(active_name)

    state2 =
      empty_store()
      |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
      |> State.new()
      |> Name.put_active(active_name)

    state1 =
      NameTransferMutation.execute(
        NameTransferMutation.new(tx, transfer_txi_idx),
        state1
      )

    state2 = Name.transfer(state2, name_hash, recipient_pk, transfer_txi_idx)
  end
end
