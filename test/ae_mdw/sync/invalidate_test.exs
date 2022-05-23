defmodule AeMdw.Db.Sync.InvalidateTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Aex9CreateContractMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Invalidate
  alias AeMdw.Db.WriteMutation

  require Model

  describe "aexn_key_dels" do
    test "return empty lists" do
      assert %{
               Model.AexnContract => [],
               Model.AexnContractName => [],
               Model.AexnContractSymbol => []
             } = Invalidate.aexn_key_dels(100..1000)
    end

    test "return keys to delete within the txi range" do
      pk1 = :crypto.strong_rand_bytes(32)
      pk2 = :crypto.strong_rand_bytes(32)
      pk3 = :crypto.strong_rand_bytes(32)
      create_txi1 = abs(System.unique_integer())
      create_txi2 = create_txi1 + 10
      create_txi3 = create_txi1 + 20
      meta_info1 = {"name1", "SYM1", 18}
      meta_info2 = {"name2", "SYM2", 18}
      meta_info3 = {"name3", "SYM3", 18}

      rev_origin1 = {create_txi1, :contract_create_tx, pk1}
      rev_origin2 = {create_txi2, :contract_create_tx, pk2}
      rev_origin3 = {create_txi3, :contract_create_tx, pk3}

      on_exit(fn ->
        Database.dirty_delete(Model.RevOrigin, rev_origin1)
        Database.dirty_delete(Model.RevOrigin, rev_origin2)
        Database.dirty_delete(Model.RevOrigin, rev_origin3)
      end)

      Database.commit([
        WriteMutation.new(Model.RevOrigin, Model.rev_origin(index: rev_origin1)),
        WriteMutation.new(Model.RevOrigin, Model.rev_origin(index: rev_origin2)),
        WriteMutation.new(Model.RevOrigin, Model.rev_origin(index: rev_origin3)),
        Aex9CreateContractMutation.new(pk1, meta_info1, {10, 0}, create_txi1),
        Aex9CreateContractMutation.new(pk2, meta_info2, {11, 0}, create_txi2),
        Aex9CreateContractMutation.new(pk3, meta_info3, {12, 0}, create_txi3)
      ])

      assert %{
               Model.AexnContract => [{:aex9, ^pk3}, {:aex9, ^pk2}],
               Model.AexnContractName => [{:aex9, "name3", ^pk3}, {:aex9, "name2", ^pk2}],
               Model.AexnContractSymbol => [{:aex9, "SYM3", ^pk3}, {:aex9, "SYM2", ^pk2}]
             } = Invalidate.aexn_key_dels(create_txi2..(create_txi2 + 100))
    end
  end
end
