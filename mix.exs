defmodule User.Mixfile do
  use Mix.Project

  def project do
    [app: :user,
     version: "0.0.1",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {User, []},
     applications: [:phoenix, :phoenix_pubsub, :phoenix_html, :cowboy, :logger, :gettext,
                    :phoenix_ecto, :timex_ecto, :postgrex, :mailgun]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:comeonin, "~> 3.0"},
     {:cowboy, "~> 1.0.0"},
     {:ex_machina, "~> 1.0", only: :test},
     {:gettext, "~> 0.11"},
     {:guardian, "~> 0.14"},
     {:jose, "~> 1.8"},
     {:mailgun, git: "git://github.com/farism/mailgun.git"},
     {:mix_test_watch, "~> 0.3.2", only: :test, runtime: false},
     {:params, "~> 2.0"},
     {:phoenix, "~> 1.2.0"},
     {:phoenix_pubsub, "~> 1.0"},
     {:phoenix_ecto, "~> 3.0"},
     {:postgrex, ">= 0.0.0"},
     {:timex, "~> 3.1"},
     {:timex_ecto, "~> 3.1"}]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["dev": ["deps", "ecto.setup", "phoenix.server"],
     "test.watch": ["deps", "ecto.reset", "test.watch"],
     "ecto.setup": ["ecto.create", "ecto.migrate"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "deps": ["deps.get", "deps.compile"]]
  end
end
