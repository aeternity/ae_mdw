defmodule AeMdw.MixProject do
  use Mix.Project

  def project() do
    [
      app: :ae_mdw,
      version: "1.0.9",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true
      ],
      aliases: aliases(),
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [
        exclude: [
          :lager,
          :mnesia,
          :aeb_aevm_abi,
          :aeb_fate_abi,
          :aeb_fate_code,
          :aeb_fate_encoding,
          :aeb_heap,
          :aec_accounts,
          :aec_block_genesis,
          :aec_block_micro_candidate,
          :aec_db,
          :aec_blocks,
          :aec_block_insertion,
          :aec_chain,
          :aec_chain_state,
          :aec_dev_reward,
          :aec_events,
          :aec_governance,
          :aec_hard_forks,
          :aec_hash,
          :aec_headers,
          :aec_sync,
          :aec_trees,
          :aect_call,
          :aect_call_tx,
          :aect_contracts,
          :aect_create_tx,
          :aect_dispatch,
          :aect_state_tree,
          :aehttp_logic,
          :aens,
          :aens_claim_tx,
          :aens_pointer,
          :aens_revoke_tx,
          :aens_update_tx,
          :aens_transfer_tx,
          :aeo_extend_tx,
          :aeo_query,
          :aeo_register_tx,
          :aeo_response_tx,
          :aeo_state_tree,
          :aeo_utils,
          :aesc_utils,
          :aeser_api_encoder,
          :aeser_contract_code,
          :aeser_id,
          :aetx,
          :aetx_env,
          :aetx_sign,
          :aeu_info,
          :aeu_mtrees
        ]
      ],
      dialyzer: dialyzer(),
      preferred_cli_env: [
        "test.integration": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application() do
    [
      mod: {AeMdw.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib", "priv/migrations"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps() do
    [
      {:ae_plugin, github: "aeternity/ae_plugin"},
      # {:aesophia, path: "deps/aesophia", app: false},
      {:stream_split, "~> 0.1.5"},
      {:ex2ms, "~> 1.6.0"},
      {:logger_file_backend, "~> 0.0.11"},
      {:smart_global, github: "ks/smart_global"},
      {:smart_record, github: "ks/smart_record"},
      {:dbg, github: "fishcakez/dbg"},
      {:phoenix, "~> 1.5.8"},
      {:plug, "~> 1.11"},
      {:cors_plug, "~> 2.0"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:riverside, "~> 1.2.6"},
      {:websockex, "~> 0.4.2"},
      {:phoenix_swagger, "~> 0.8"},
      {:temp, "~> 0.4"},
      {:tesla, "~> 1.3.0"},
      {:assertions, "~> 0.18.1", only: [:test]},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:phoenix_html, "~> 2.11"}
    ]
  end

  defp aliases do
    %{
      test: ["test --exclude integration"],
      "test.integration": ["test --only integration"]
    }
  end

  defp dialyzer do
    [
      plt_ignore_apps: [:mnesia],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end
end
