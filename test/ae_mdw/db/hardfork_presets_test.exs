defmodule AeMdw.Db.HardforkPresetsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import Mock

  setup_all do
    clear_import()
    on_exit(fn -> HardforkPresets.import_account_presets() end)
  end

  describe "import_account_presets" do
    test "on mainnet saves genesis, minerva, fortuna and lima migrated accounts" do
      with_mocks [{:aec_governance, [:passthrough], get_network_id: fn -> "ae_mainnet" end}] do
        HardforkPresets.import_account_presets()

        assert 716 ==
                 State.new()
                 |> Collection.stream(
                   Model.KindIntTransferTx,
                   {"accounts_genesis", nil, nil, nil}
                 )
                 |> Stream.take_while(&match?({"accounts_genesis", _bi, _target, _txi}, &1))
                 |> Enum.count()

        assert 325 ==
                 State.new()
                 |> Collection.stream(
                   Model.KindIntTransferTx,
                   {"accounts_minerva", nil, nil, nil}
                 )
                 |> Stream.take_while(&match?({"accounts_minerva", _bi, _target, _txi}, &1))
                 |> Enum.count()

        assert 304 ==
                 State.new()
                 |> Collection.stream(
                   Model.KindIntTransferTx,
                   {"accounts_fortuna", nil, nil, nil}
                 )
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

        clear_import()
      end
    end

    test "on testnet saves genesis, minerva, fortuna and lima migrated accounts" do
      with_mocks [{:aec_governance, [:passthrough], get_network_id: fn -> "ae_uat" end}] do
        HardforkPresets.import_account_presets()

        assert 1 ==
                 State.new()
                 |> Collection.stream(
                   Model.KindIntTransferTx,
                   {"accounts_genesis", nil, nil, nil}
                 )
                 |> Stream.take_while(&match?({"accounts_genesis", _bi, _target, _txi}, &1))
                 |> Enum.count()

        assert 3 ==
                 State.new()
                 |> Collection.stream(
                   Model.KindIntTransferTx,
                   {"accounts_minerva", nil, nil, nil}
                 )
                 |> Stream.take_while(&match?({"accounts_minerva", _bi, _target, _txi}, &1))
                 |> Enum.count()

        clear_import()
      end
    end

    test "on custom network skips importing accounts" do
      with_mocks [{:aec_governance, [:passthrough], get_network_id: fn -> "ae_custom" end}] do
        HardforkPresets.import_account_presets()

        assert Database.count(Model.KindIntTransferTx) == 0
        clear_import()
      end
    end
  end

  describe "mint_sum" do
    test "returns the sum of mintings of a hardfork" do
      assert HardforkPresets.mint_sum(:roma) == 89_451_376_822_397_976_634_367_408
      assert HardforkPresets.mint_sum(:minerva) == 27_051_422_546_127_651_538_826_703
      assert HardforkPresets.mint_sum(:fortuna) == 72_681_157_406_723_951_132_840_970
      assert HardforkPresets.mint_sum(:lima) == 86_948_638_040_240_004_719_633_952
    end
  end

  defp clear_import do
    state = State.new()

    for model <- [Model.KindIntTransferTx, Model.IntTransferTx, Model.TargetKindIntTransferTx] do
      state
      |> Collection.stream(model, nil)
      |> Enum.to_list()
      |> Enum.each(&State.delete(State.new(), model, &1))
    end
  end
end
