defmodule Loader.Config.SysEnv do

  @behaviour Loader.Config

  def get_in(keys) do
    sys_var_name = var_name_to_sys_env(keys)
    case System.get_env(sys_var_name) do
      nil -> {:error, :not_found}
      val -> string_to_term(val)
    end
  end

  defp string_to_term(val) do
    try do
      {result, _bindings} = Code.eval_string(val)
      {:ok, result}
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp var_name_to_sys_env(keys) do
    prefix = "LOADER_"
    subject = Enum.map(keys, &Atom.to_string/1)
    |> Enum.map(&String.upcase/1)
    |> Enum.join("_")
    prefix <> subject
  end
end
