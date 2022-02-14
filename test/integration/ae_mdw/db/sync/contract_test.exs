defmodule Integration.AeMdw.Db.Sync.ContractTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AeMdw.Contract
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.Sync
  alias AeMdw.Database

  require Model

  describe "events_mutations/4" do
    test "creates name transfer mutation" do
      {"AENS.transfer", call_txi, _local_idx} =
        Database.dirty_next(Model.FnameIntContractCall, {"AENS.transfer", -1, -1})

      [Model.tx(block_index: {height, mbi} = block_index, id: tx_hash)] =
        Database.read(Model.Tx, call_txi)

      {_key_block, micro_blocks} = NodeDb.get_blocks(height)

      event_mutations =
        micro_blocks
        |> Enum.at(mbi)
        |> Contract.get_grouped_events()
        |> Map.fetch!(tx_hash)
        |> Sync.Contract.events_mutations(block_index, <<>>, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameTransferMutation{
                 txi: ^call_txi,
                 block_index: ^block_index
               } ->
                 true

               %{} ->
                 false
             end)
    end

    test "creates name update mutation" do
      {"AENS.update", call_txi, _local_idx} =
        Database.dirty_next(Model.FnameIntContractCall, {"AENS.update", -1, -1})

      [Model.tx(block_index: {height, mbi} = block_index, id: tx_hash)] =
        Database.read(Model.Tx, call_txi)

      {_key_block, micro_blocks} = NodeDb.get_blocks(height)

      event_mutations =
        micro_blocks
        |> Enum.at(mbi)
        |> Contract.get_grouped_events()
        |> Map.fetch!(tx_hash)
        |> Sync.Contract.events_mutations(block_index, <<>>, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameUpdateMutation{
                 txi: ^call_txi,
                 block_index: ^block_index
               } ->
                 true

               %{} ->
                 false
             end)
    end
  end
end
