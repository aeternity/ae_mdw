ExUnit.start()

# Optional heavy reset only when explicitly requested to avoid races with running sync processes.
if System.get_env("AE_MDW_FORCE_DB_RESET") == "1" do
  IO.puts("[test_helper] Forcing DB reset (AE_MDW_FORCE_DB_RESET=1)")
  # Best effort shutdown to reduce lingering processes; ignore errors.
  _ = try do
    Application.stop(:aecore)
  rescue
    _ -> :ok
  end

  # Create counters table if not present
  unless :ets.whereis(:counters) != :undefined do
    :ets.new(:counters, [:named_table, :set, :public])
  end
  for kv <- [{:txi, 0}, {:kbi, 0}] do
    :ets.insert(:counters, kv)
  end

  # Close & reopen RocksDB defensively
  _ = try do
    AeMdw.Db.RocksDb.close()
  rescue
    _ -> :ok
  end
  case AeMdw.Db.RocksDb.open(true) do
    :ok -> :persistent_term.put({:aec_db, :backend_module}, "rocksdb")
    other -> IO.puts("[test_helper] Skipping persistent_term init, open returned: #{inspect(other)}")
  end
end

Mneme.start()
