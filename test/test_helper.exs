ExUnit.start()

# Ranch is a direct OTP dependency of aecore and starts regardless of app_ctrl
# mode. The aec_peer listener fires errors when aec_keys isn't ready in tests.
# There is no startup config to prevent this; suppress at the OTP logger level.
:logger.set_application_level(:ranch, :none)

unless :ets.whereis(:counters) != :undefined do
  :ets.new(:counters, [:named_table, :set, :public])
end

for kv <- [{:txi, 0}, {:kbi, 0}] do
  :ets.insert_new(:counters, kv)
end

if :persistent_term.get({:aec_db, :backend_module}, nil) == nil do
  :persistent_term.put({:aec_db, :backend_module}, "rocksdb")
end

# Optional heavy reset only when explicitly requested to avoid races with running sync processes.
if System.get_env("AE_MDW_FORCE_DB_RESET") == "1" do
  IO.puts("[test_helper] Forcing DB reset (AE_MDW_FORCE_DB_RESET=1)")
  # Best effort shutdown to reduce lingering processes; ignore errors.
  _stop_result =
    try do
      Application.stop(:aecore)
    rescue
      _stop_error -> :ok
    end

  for kv <- [{:txi, 0}, {:kbi, 0}] do
    :ets.insert(:counters, kv)
  end

  # Close & reopen RocksDB defensively
  _close_result =
    try do
      AeMdw.Db.RocksDb.close()
    rescue
      _close_error -> :ok
    end

  case AeMdw.Db.RocksDb.open(true) do
    :ok ->
      :persistent_term.put({:aec_db, :backend_module}, "rocksdb")

    other ->
      IO.puts("[test_helper] Skipping persistent_term init, open returned: #{inspect(other)}")
  end
end

Mneme.start()
