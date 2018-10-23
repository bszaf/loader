# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :loader,
  # defines sources of config variables
  config_handlers: [Loader.Config.SysEnv, Loader.Config.AppEnv]

config :epmdless,
    transport: :tcp,
    listen_port: 17012

#     import_config "#{Mix.env()}.exs"
