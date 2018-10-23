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
        put_in(acc, path, transform.(var_val))
    end
  end

  defp overwriteable_vars do
    [
      epmdless: [
        # [path in env vars,  OS var name           transform function
        {[:listen_port], "LOADER_EPMD_LISTEN_PORT", &String.to_integer/1}
      ]
    ]
  end

end
