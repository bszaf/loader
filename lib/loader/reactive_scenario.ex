defmodule Loader.ReactiveScenario do

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      import Loader.ReactiveScenario
      @before_compile Loader.ReactiveScenario

      # default implementations
      def handle_info(_any, state), do: {:ok, state}

      def pre_init(), do: {:ok, %{}}

      def init(state), do: {:ok, state}

      defoverridable pre_init: 0, init: 1, handle_info: 2
    end
  end

  defmacro rule(opts) do
    opts = Macro.escape(opts)
    quote do
      @rules unquote(opts)
    end
  end

  defmacro __before_compile__(env) do
    raw_rules = Module.get_attribute(env.module, :rules)
    overwriteable_default_rules =
      (
        quote(do: (any -> handle_info(any, state)))
      )
    default_rules =
      (
        quote(do: ({:'$control', opts} = control -> control))
      )
    rules = Enum.flat_map(raw_rules, fn opts ->
      match = Keyword.get(opts, :match)
      handler = maybe_to_atom(Keyword.get(opts, :handler))
      quote do: (unquote(match) = received -> unquote(handler)(received, state))
    end)
    receive_block = List.flatten([default_rules, rules, overwriteable_default_rules])
    b = quote do
      def receive_do(state) do
        receive do
          unquote(receive_block)
        end
      end
    end
    #IO.puts Macro.to_string(b)
    b
  end

  defp maybe_to_atom(a) when is_atom(a), do: a
  defp maybe_to_atom({a, _line, _env}) when is_atom(a), do: a

end

defmodule Test do

  use Loader.ReactiveScenario
  require Logger

  rule match: {:tcp, _}, handler: :handle_tcp
  rule match: :tick, handler: handle_tick
  rule match: :tock, handler: handle_tock

  def init(state) do
    :erlang.send_after(1000, self(), :tick)
    {:ok, state}
  end

  def handle_tcp(_msg, state) do
    {:ok, state}
  end

  def handle_tick(_, state) do
    :erlang.send_after(1000, self(), :tock)
    {:ok, state}
  end

  def handle_tock(_, state) do
    :erlang.send_after(1000, self(), :tick)
    {:ok, state}
  end



end
