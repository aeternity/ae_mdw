config = ExUnit.configuration()
included_tests = Keyword.fetch!(config, :include)

if Enum.all?(~w(integration iteration devmode)a, &(&1 not in included_tests)) do
  IO.puts("Stopping :aecore..")
  Application.stop(:aecore)

  :ets.new(:counters, [:named_table, :set, :public])
  :ets.insert(:counters, {:txi, 0})
  :ets.insert(:counters, {:kbi, 0})

  # reset database
  :ok = AeMdw.Db.RocksDb.close()
  :ok = AeMdw.Db.RocksDb.open(true)

  # init for tests without sync
  :persistent_term.put({:aec_db, :backend_module}, "rocksdb")
end

ExUnit.start()
