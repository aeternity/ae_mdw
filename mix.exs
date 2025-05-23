defmodule AeMdw.MixProject do
  use Mix.Project

  @spec project() :: Keyword.t()
  def project() do
    [
      app: :ae_mdw,
      version: "1.104.3",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true
      ],
      aliases: aliases(),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [
        exclude: [
          :aecore,
          :lager,
          :mnesia,
          :aeb_aevm_abi,
          :aeb_fate_abi,
          :aeb_fate_code,
          :aeb_fate_encoding,
          :aeb_heap,
          :aec_accounts,
          :aec_accounts_trees,
          :aec_block_genesis,
          :aec_block_micro_candidate,
          :aec_db,
          :aec_blocks,
          :aec_block_insertion,
          :aec_chain,
          :aec_chain_state,
          :aec_chain_hc,
          :aec_consensus,
          :aec_consensus_hc,
          :aec_consensus_bitcoin_ng,
          :aec_dev_reward,
          :aec_dry_run,
          :aec_events,
          :aec_fork_block_settings,
          :aec_governance,
          :aec_hard_forks,
          :aec_hash,
          :aec_headers,
          :aec_parent_connector,
          :aec_paying_for_tx,
          :aec_spend_tx,
          :aec_sync,
          :aec_trees,
          :aec_tx_pool,
          :aect_call,
          :aect_call_tx,
          :aect_contracts,
          :aect_create_tx,
          :aect_dispatch,
          :aect_state_tree,
          :aefa_fate_code,
          :aega_attach_tx,
          :aega_call,
          :aega_meta_tx,
          :aehttp_logic,
          :aens,
          :aens_claim_tx,
          :aens_hash,
          :aens_pointer,
          :aens_revoke_tx,
          :aens_update_tx,
          :aens_transfer_tx,
          :aeo_extend_tx,
          :aeo_oracles,
          :aeo_query,
          :aeo_query_tx,
          :aeo_register_tx,
          :aeo_response_tx,
          :aeo_state_tree,
          :aeo_utils,
          :aesc_channels,
          :aesc_close_mutual_tx,
          :aesc_close_solo_tx,
          :aesc_create_tx,
          :aesc_deposit_tx,
          :aesc_force_progress_tx,
          :aesc_offchain_tx,
          :aesc_settle_tx,
          :aesc_snapshot_solo_tx,
          :aesc_set_delegates_tx,
          :aesc_slash_tx,
          :aesc_utils,
          :aesc_withdraw_tx,
          :aeser_api_encoder,
          :aeser_contract_code,
          :aeser_id,
          :aetx,
          :aetx_env,
          :aetx_sign,
          :aeu_env,
          :aeu_info,
          :aeu_logging_env,
          :aeu_mtrees,
          :aeu_time,
          :app_ctrl,
          :app_ctrl_server,
          :enacl,
          :sext,
          :rocksdb,
          :telemetry,
          :aeapi
        ]
      ],
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "test.integration": :test,
        "test.iteration": :test,
        "mneme.watch": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  @spec application() :: Keyword.t()
  def application() do
    [
      mod: {AeMdw.Application, []},
      start_phases: [
        migrate_db: [],
        hardforks_presets: [],
        load: [],
        start_sync: []
      ],
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib", "priv/migrations"]

  # Specifies your project dependencies.
  defp deps() do
    [
      {:ae_plugin, github: "aeternity/ae_plugin", ref: "82c6372"},
      {:stream_split, "~> 0.1.5"},
      {:ex2ms, "~> 1.6.0"},
      {:logger_file_backend, "~> 0.0.11"},
      {:logger_json, "~> 5.0"},
      {:phoenix, "~> 1.7.18"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:bandit, "~> 1.5"},
      {:cors_plug, "~> 3.0"},
      {:telemetry, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_statsd, "~> 0.6"},
      {:plug, "~> 1.13"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:jsx, "~> 2.8.0"},
      {:plug_cowboy, "~> 2.5"},
      {:websockex, "~> 0.4.3"},
      {:tesla, "~> 1.5"},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:git_hooks, "~> 0.5.0", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.14", only: :test},
      {:gen_state_machine, "~> 2.0"},
      {:mneme, "~> 0.9", only: [:dev, :test]}
    ]
  end

  defp aliases do
    %{
      test: ["test --exclude integration --exclude devmode"],
      "test.integration": ["test --only integration"],
      "test.iteration": ["test --only iteration"],
      "test.devmode": ["test --only devmode"]
    }
  end

  defp dialyzer do
    [
      plt_ignore_apps: [:mnesia],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [:unmatched_returns]
    ]
  end
end
