defmodule AeMdw.MixProject do
  use Mix.Project

  def project do
    [
      app: :ae_mdw,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AeMdw.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases, do: [test: "test --no-start"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ae_plugin, github: "aeternity/ae_plugin"},
      {:stream_split, "~> 0.1.5"},
      {:ex2ms, "~> 1.6.0"},
      {:logger_file_backend, "~> 0.0.11"},
      {:smart_global, github: "ks/smart_global"},
      {:dbg, github: "fishcakez/dbg"},
      {:phoenix, "~> 1.4.13"},
      {:phoenix_pubsub, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:riverside, "~> 1.2.3"},
      {:websockex, "~> 0.4.2"},
      {:phoenix_swagger, "~> 0.8"}
    ]
  end
end
