use Mix.Config

# customizable per developer
config :git_hooks,
  auto_install: false,
  hooks: [
    pre_commit: [
      verbose: true,
      tasks: [
        "mix format --check-formatted --dry-run --check-equivalent"
      ]
    ],
    pre_push: [
      verbose: true,
      tasks: [
        "mix compile --all-warnings --warnings-as-errors",
        "elixir --sname aeternity@localhost -S mix test"
        # "mix credo --strict",
      ]
    ]
  ]
