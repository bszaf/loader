defmodule Loader do
  @moduledoc """
  Documentation for Loader.
  """

  def max_queue() do
    [{_pid, count, _info}] = :recon.proc_count(:message_queue_len, 1)
    count
  end
end
