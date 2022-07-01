defmodule AeMdw.Db.NameClaimMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync

  import Mock

  require Model

  test "claim an inactive name with timeout 0" do
    plain_name = "claim.test"

    new_owner_pk =
      <<11, 180, 237, 121, 39, 249, 123, 81, 225, 188, 181, 225, 52, 13, 18, 51, 91, 42, 43, 18,
        200, 188, 82, 33, 214, 60, 75, 203, 57, 212, 30, 97>>

    tx =
      {:ns_claim_tx, {:id, :account, new_owner_pk}, 11_251, plain_name, 7, :prelima,
       1_000_000_000_000_000, 0}

    tx_hash =
      <<159, 240, 103, 205, 63, 165, 186, 153, 226, 186, 128, 241, 61, 192, 66, 89, 156, 217, 200,
        247, 31, 137, 16, 129, 250, 190, 199, 100, 137, 179, 112, 165>>

    claim_height = 200
    old_claim_height = 100
    old_claims = [{{old_claim_height, 1}, 123}]
    owner_pk = <<8435::256>>
    block_index = {claim_height, 0}
    txi = 223

    inactive_name =
      Model.name(
        index: plain_name,
        active: old_claim_height,
        expire: 199,
        claims: old_claims,
        updates: [{{150, 0}, 173}],
        owner: owner_pk,
        previous: nil
      )

    Database.dirty_write(Model.InactiveName, inactive_name)

    Database.dirty_write(
      Model.InactiveNameExpiration,
      Model.expiration(index: {199, plain_name})
    )

    Database.dirty_write(
      Model.InactiveNameOwner,
      Model.owner(index: {owner_pk, plain_name})
    )

    with_mocks [
      {AeMdw.Db.Util, [], [proto_vsn: fn _height -> 3 end]}
    ] do
      tx
      |> Sync.Name.name_claim_mutations(tx_hash, block_index, txi)
      |> Database.commit()
    end

    state = State.new()

    assert {:ok,
            Model.name(
              index: ^plain_name,
              active: ^claim_height,
              claims: [{block_index, txi} | old_claims],
              expire: expire,
              owner: ^new_owner_pk,
              updates: []
            )} = State.get(state, Model.ActiveName, plain_name)

    assert State.exists?(state, Model.ActiveNameActivation, {claim_height, plain_name})
    assert State.exists?(state, Model.ActiveNameExpiration, {expire, plain_name})
    assert State.exists?(state, Model.ActiveNameOwner, {new_owner_pk, plain_name})
  end
end
