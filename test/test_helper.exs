config = ExUnit.configuration()

if :integration not in Keyword.fetch!(config, :include) do
  IO.puts("Stopping :aecore..")
  Application.stop(:aecore)

  :ets.new(:counters, [:named_table, :set, :public])
  :ets.insert(:counters, {:txi, 0})
  :ets.insert(:counters, {:kbi, 0})

  # reset database
  alias AeMdw.Db.RocksDb

  :ok = RocksDb.close()
  dir = Application.fetch_env!(:ae_mdw, RocksDb)[:data_dir]
  {:ok, _} = File.rm_rf(dir)
  :ok = RocksDb.open()
end

ExUnit.start()
