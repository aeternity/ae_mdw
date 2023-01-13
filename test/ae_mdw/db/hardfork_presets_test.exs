defmodule AeMdw.Db.HardforkPresetsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import Mock

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

  test "saves genesis, fortuna and lima migrated accounts skipping minerva ones" do
    State.new()
    |> Collection.stream(
      Model.KindIntTransferTx,
      {"", nil, nil, nil}
    )
    |> Enum.to_list()
    |> Enum.each(&Database.delete(Model.KindIntTransferTx, &1))

    with_mocks [
      {:aeu_env, [:passthrough],
       [
         user_map: fn ->
           %{
             "chain" => %{
               "hard_forks" => %{
                 "5" => 0
               },
               "garbage_collection" => %{
                 "enabled" => false,
                 "history" => 500,
                 "interval" => 3
               },
               "persist" => true
             },
             "fork_management" => %{"network_id" => "ae_mainnet"},
             "http" => %{"external" => %{"port" => 3013}, "internal" => %{"port" => 3113}},
             "keys" => %{"dir" => "keys", "peer_password" => "secret"},
             "mining" => %{
               "autostart" => false,
               "beneficiary" => "ak_2Dri7n9Bm2FgdN5ZFXzDn1ZAXUMox6roEWTfU1rCQ842pTdWiK"
             },
             "sync" => %{"log_peer_connection_count_interval" => 6_000_000, "port" => 3015},
             "system" => %{"plugin_path" => "/home/aeternity/node/ae_mdw/plugins"},
             "websocket" => %{"channel" => %{"port" => 3014}}
           }
         end
       ]}
    ] do
      HardforkPresets.import_account_presets()

      assert 716 ==
               State.new()
               |> Collection.stream(Model.KindIntTransferTx, {"accounts_genesis", nil, nil, nil})
               |> Stream.take_while(&match?({"accounts_genesis", _bi, _target, _txi}, &1))
               |> Enum.count()

      assert 0 ==
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
