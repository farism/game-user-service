# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :user,
  ecto_repos: [User.Repo]

# Configures the endpoint
config :user, User.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kHXi52dja26vcGs4ryxd43Hsr9RULFwna1XAkhHPf4vqGeZWkiIFYVifB/RxDXRA",
  render_errors: [view: User.ErrorView, accepts: ~w(json)],
  pubsub: [name: User.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :guardian, Guardian,
  allowed_algos: ["HS512"], # optional
  verify_module: Guardian.JWT,  # optional
  issuer: "Users",
  ttl: { 30, :days },
  allowed_drift: 2000,
  verify_issuer: true, # optional
  secret_key: {Users.GuardianSecretKey, :fetch},
  serializer: Users.GuardianSerializer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
import_config "prod.secret.exs"
