# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :loader,
  # defines sources of config variables
  config_handlers: [Loader.Config.SysEnv, Loader.Config.AppEnv]

config :exometer_core,
  predefined: [
    {
      [:erlang, :system_info],
      {:function, :erlang, :system_info, [:'$dp'], :value, [:port_count, :process_count]},
      []
    },
    {
      [:erlang, :memory],
      {:function, :erlang, :memory, [:'$dp'], :value, [:total, :processes, :processes_used, :system, :binary, :ets]},
      []
    }
  ],
  report: [
    reporters: [
      exometer_report_graphite: [
        host: '10.100.0.140',
        port: 2003,
        prefix: "loader.local.loader",
        api_key: ''
      ]
    ]
  ],
  subscribers: [
    {:exometer_report_graphite, [:erlang, :system_info], [:port_count, :process_count], 10000, true},
    {:exometer_report_graphite, [:erlang, :memory], [:total, :processes, :processes_used, :system, :binary, :ets], 10000, true}
  ]
import_config "#{Mix.env()}.exs"
