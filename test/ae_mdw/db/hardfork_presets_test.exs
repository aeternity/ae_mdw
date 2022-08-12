defmodule AeMdw.Db.HardforkPresetsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  describe "import_account_presets" do
    test "saves genesis, minerva, fortuna and lima migrated accounts" do
      HardforkPresets.import_account_presets()

      assert 716 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"accounts_genesis", nil, nil, nil})
               |> Stream.take_while(&match?({"accounts_genesis", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 325 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"accounts_minerva", nil, nil, nil})
               |> Stream.take_while(&match?({"accounts_minerva", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 304 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"accounts_fortuna", nil, nil, nil})
               |> Stream.take_while(&match?({"accounts_fortuna", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 702 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"accounts_lima", nil, nil, nil})
               |> Stream.take_while(&match?({"accounts_lima", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 1 ==
               State.new()
               |> Collection.stream(
                 Model.KindIntTransferTx,
                 {"accounts_extra_lima", nil, nil, nil}
               )
               |> Stream.take_while(&match?({"accounts_extra_lima", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 1 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"contracts_lima", nil, nil, nil})
               |> Stream.take_while(&match?({"contracts_lima", _bi, _target, _txi}, &1))
               |> Enum.count()
    end
  end
end
