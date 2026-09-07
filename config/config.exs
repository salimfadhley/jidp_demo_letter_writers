import Config

config :jido_demo1, JidoDemo1.Jido,
  max_tasks: 100,
  agent_pools: []

import_config "#{config_env()}.exs"
