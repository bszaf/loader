defmodule Loader.Config do

  import Kernel, except: [get_in: 2]

  @callback get_in([Atom.t]) :: {:ok, any} | {:error, :not_found}


  def get(key, default \\ nil), do: get_in([key], default)

  def get_in(keys, default \\ nil) do
    handlers = Application.get_env(:loader, :config_handlers, default_handlers())
    Enum.reduce_while(handlers, default, &(reducer(keys, &1, &2)))
  end

  def get_app_env(key, default \\ nil),
    do: Application.get_env(:loader, key, default)

  defp default_handlers, do: [Loader.Config.SysEnv, Loader.Config.AppEnv]

  defp reducer(keys, handler, acc) do
    case handler.get_in(keys) do
      {:error, :not_found} ->
        {:cont, acc}
      {:ok, val} ->
        {:halt, val}
    end
  end

end
