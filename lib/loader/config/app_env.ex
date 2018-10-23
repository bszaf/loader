defmodule Loader.Config.AppEnv do

  @behaviour Loader.Config

  def get_in(keys) do
    Application.get_all_env(:loader)
    |> Kernel.get_in(keys)
    |> case do
      nil -> {:error, :not_found}
      val -> {:ok, val}
    end
  end

end
