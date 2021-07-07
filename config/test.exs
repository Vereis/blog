use Mix.Config

config :blog, Blog.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("DB_NAME") <> "_test",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :blog_web, BlogWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
