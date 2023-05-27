config = ExUnit.configuration()
included_tests = Keyword.fetch!(config, :include)

if :integration not in included_tests and :iteration not in included_tests do
  IO.puts("Stopping :aecore..")
  Application.stop(:aecore)

  :ets.new(:counters, [:named_table, :set, :public])
  :ets.insert(:counters, {:txi, 0})
  :ets.insert(:counters, {:kbi, 0})

  # reset database
  alias AeMdw.Db.RocksDb

  :ok = RocksDb.close()
  :ok = RocksDb.open(true)
end

ExUnit.start()
