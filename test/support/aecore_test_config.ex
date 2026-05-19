defmodule AeMdw.AecoreTestConfig do
  @moduledoc """
  Setup hook that runs at phase 999, before aecore's `set_app_ctrl_mode` hook
  at phase 1000. Re-applies the maintenance-mode config so that `aesync` is
  never started during tests, regardless of what the node's sys.config says.
  """

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
  end
end
