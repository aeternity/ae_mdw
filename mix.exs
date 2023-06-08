defmodule AeMdw.MixProject do
  use Mix.Project

  @version "1.48.1"

  def project() do
    [
      app: :ae_mdw,
      version: @version,
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
          :aec_consensus,
          :aec_consensus_bitcoin_ng,
          :aec_dev_reward,
          :aec_dry_run,
          :aec_events,
          :aec_fork_block_settings,
          :aec_governance,
          :aec_hard_forks,
          :aec_hash,
          :aec_headers,
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
          :aeu_mtrees,
          :app_ctrl,
          :app_ctrl_server,
          :enacl,
          :sext,
          :rocksdb,
          :telemetry
        ]
      ],
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "test.integration": :test,
        "test.iteration": :test
      ],
      releases: [
        ae_mdw: fn ->
          if is_nil(System.get_env("INCLUDE_LOCAL_NODE")) do
            []
          else
            [
              steps: [&build_node/1, &copy_node/1, :assemble, :tar, &remove_node/1],
              overlays: ["node-tmp"],
              version: "v" <> @version <> "-" <> to_string(:erlang.system_info(:system_architecture))
            ]
          end

        end
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application() do
    [
      mod: {AeMdw.Application, []},
      start_phases: [migrate_db: [], hardforks_presets: [], dedup_accounts: [], start_sync: []],
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib", "priv/migrations"]

  # Specifies your project dependencies.
  defp deps() do
    [
      {:ae_plugin, github: "aeternity/ae_plugin"},
      {:stream_split, "~> 0.1.5"},
      {:ex2ms, "~> 1.6.0"},
      {:logger_file_backend, "~> 0.0.11"},
      {:logger_json, "~> 5.0"},
      {:smart_global, github: "ks/smart_global"},
      {:phoenix, "~> 1.6.12"},
      {:phoenix_html, "~> 3.0"},
      {:telemetry, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_statsd, "~> 0.6"},
      {:phoenix_live_view, "~> 0.18"},
      {:phoenix_live_dashboard, "~> 0.7"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:plug, "~> 1.13"},
      {:cors_plug, "~> 2.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"},
      {:websockex, "~> 0.4.3"},
      {:tesla, "~> 1.5"},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:git_hooks, "~> 0.5.0", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0.0", only: [:dev]},
      {:excoveralls, "~> 0.14", only: :test},
      {:gen_state_machine, "~> 2.0"}
    ]
  end

  defp aliases do
    %{
      test: ["test --exclude integration"],
      "test.integration": ["test --only integration"],
      "test.iteration": ["test --only iteration"]
    }
  end

  defp dialyzer do
    [
      plt_ignore_apps: [:mnesia],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [
        :unmatched_returns,
        :race_conditions
      ]
    ]
  end

  defp build_node(release) do
    node_path = node_build_root()
    IO.inspect(node_path, label: "Building node in directory")
    {_, 0} = System.cmd("make", ["prod-package"], cd: node_path)
    release
  end

  defp copy_node(release) do
    tar_file = node_tar_file()
    File.rm_rf("node-tmp")
    File.mkdir_p("node-tmp/local/rel/aeternity/data/mnesia")
    IO.inspect(tar_file, label: "Using aeternity release")
    :erl_tar.extract(tar_file, [:compressed, {:cwd, "node-tmp/local/rel/aeternity"}])
    release
  end

  defp remove_node(release) do
    File.rm_rf("node-tmp")
    release
  end

  defp node_build_root() do
    System.get_env("NODE_BUILD_ROOT", "../aeternity/")
  end

  defp node_tar_file() do
    reldir = Path.join(node_build_root(), "_build/prod/rel/aeternity")
    files = File.ls!(reldir)
    tar_file = latest_tar_file(files, reldir)
    Path.join(reldir, tar_file)
  end

  defp latest_tar_file(files, reldir) do
    files
    |> Enum.filter(fn file -> String.ends_with?(file, ".tar.gz") end)
    |> Enum.filter(fn file -> String.starts_with?(file, "aeternity") end)
    |> Enum.map(fn file -> {file, File.lstat!(Path.join(reldir, file))} end)
    |> Enum.sort(fn {_, f1}, {_, f2} -> f1.ctime > f2.ctime end)
    |> Enum.map(fn {file, _} -> file end)
    |> List.first()
  end

end
