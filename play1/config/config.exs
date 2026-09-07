import Config

config :play1, Play1.Jido,
  max_tasks: 100,
  agent_pools: []

# A letter can take a model well over Jido's 30 s default, especially with a retry.
config :jido_action, default_timeout: 240_000

import_config "#{config_env()}.exs"
