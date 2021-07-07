use Mix.Config

config :blog,
  ecto_repos: [Blog.Repo],
  access_token: System.get_env("ACCESS_TOKEN"),
  repo: System.get_env("REPO_NAME"),
  owner: System.get_env("REPO_OWNER")

config :blog, Blog.Repo,
  database: System.get_env("DB_NAME"),
  username: System.get_env("DB_USER"),
  password: System.get_env("DB_PASSWORD"),
  port: System.get_env("DB_PORT")

config :blog_web,
  ecto_repos: [Blog.Repo],
  generators: [context_app: :blog]

# Configures the endpoint
config :blog_web, BlogWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "CBstNw5JifWeRKBvZeH8zHXEhRaMY9BRwnuDWL7aMWAe3wcoHmqD3Y/ZNNJYp75w",
  render_errors: [view: BlogWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Blog.PubSub,
  live_view: [signing_salt: "yKjH5K6a"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
