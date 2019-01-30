defmodule Loader.Config.Provider do

  require Logger

  def init(_) do
    Enum.each(overwriteable_vars(), &set_envs_for_app/1)
  end

  def set_envs_for_app({application, envs}) do
    defaults = Application.get_all_env(application)
    new_vars = Enum.reduce(envs, defaults, &set_var_reducer/2)
    for {k, v} <- new_vars do
      Application.put_env(application, k, v, persistent: true)
    end
  end

  def set_var_reducer({path, os_env}, acc),
    do: set_var_reducer({path, os_env, fn x -> x end}, acc)

  def set_var_reducer({path, os_env, transform}, acc) do
    case System.get_env(os_env) do
      nil ->
        acc
      var_val ->
        go_deep(path, transform.(var_val), acc)
    end
  end

  defp go_deep([last_key], new_val, acc) do
    Keyword.put(acc, last_key, new_val)
  end
  defp go_deep([k | t], new_val, acc) do
    modified_value = Keyword.get(acc, k, [])
    Keyword.put(acc, k, go_deep(t, new_val, modified_value))
  end

  defp overwriteable_vars do
    [
      exometer_core: [
        {[:report, :reporters, :exometer_report_graphite, :host], "LOADER_GRAPHITE_HOST", &String.to_charlist/1},
        {[:report, :reporters, :exometer_report_graphite, :port], "LOADER_GRAPHITE_PORT", &String.to_integer/1}
      ]

      ## application: [
      #      [
      #        # [path in env vars,  OS var name           transform function
      #        {[:listen_port], "LOADER_EPMD_LISTEN_PORT", &String.to_integer/1}
      #      ]
    ]
  end

end
