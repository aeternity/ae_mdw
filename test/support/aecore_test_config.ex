defmodule AeMdw.AecoreTestConfig do
  @moduledoc """
  Setup hook that runs at phase 999, before aecore's `set_app_ctrl_mode` hook
  at phase 1000. Re-applies the maintenance-mode config so that `aesync` is
  never started during tests, regardless of what the node's sys.config says.
  """

  @spec configure() :: :ok
  def configure do
    :application.set_env(:aecore, :"$app_ctrl",
      roles: [
        basic: [],
        nosync: [:aehttp, :aemon],
        active: [:aesync, :aehttp, :aemon, :aestratum],
        dev: [:aehttp, :aedevmode]
      ],
      mode: :maintenance,
      modes: [
        normal: [:basic, :active],
        offline: [:basic, :nosync],
        maintenance: [:basic],
        dev_mode: [:basic, :dev]
      ],
      modify: [protected_mode_apps: [add: [:lager, :mnesia]]]
    )

    # Maintenance mode skips the aecore boot path that calls
    # aec_db:put_backend_module/1, so :aec_db.get_backend_module/0 crashes
    # in tests that reach it via passthrough mocks (e.g. aec_chain → aec_db).
    # Pre-populate the term here, matching AeMdw.Db.RocksDb.open/1's value.
    :persistent_term.put({:aec_db, :backend_module}, "rocksdb")
  end
end
