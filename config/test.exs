use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :user, User.Endpoint,
  http: [port: 4011],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :guardian, Guardian,
  allowed_algos: ["RS512"], # optional
  verify_module: Guardian.JWT,  # optional
  issuer: "User",
  ttl: { 30, :days },
  allowed_drift: 2000,
  verify_issuer: true, # optional
  secret_key: {User.GuardianSecretKeyFixture, :fetch},
  serializer: User.GuardianSerializer

# Configure your database
config :user, User.Repo,
  adapter: Ecto.Adapters.Postgres,
  hostname: System.get_env("POSTGRES_HOST"),
  port: System.get_env("POSTGRES_PORT"),
  username: System.get_env("POSTGRES_USER"),
  password: System.get_env("POSTGRES_PASSWORD"),
  database: System.get_env("POSTGRES_DB"),
  pool: Ecto.Adapters.SQL.Sandbox
