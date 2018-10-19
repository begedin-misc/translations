# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :translations,
  ecto_repos: [Translations.Repo]

# Configures the endpoint
config :translations, TranslationsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Ay96jBCm9OM7Eb4kdcAGCt7DfD460TSZWwJa66ZDg/BTPC6mjdu+zcN+OtnyPHVk",
  render_errors: [view: TranslationsWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Translations.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
