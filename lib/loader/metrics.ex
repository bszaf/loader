defmodule Loader.Metrics do

  def init_metric(metric, type) do
    case available_reporter() do
      {:ok, r} ->
        init_metric(metric, type, r)
      error ->
        error
    end
  end

  def init_metric(metric, type, reporter),
    do: init_metric(metric, type, reporter, default_datapoints(type))

  def init_metric(metric, type, reporter, datapoints) do
    :exometer.re_register(metric, type, [])
    :exometer_report.unsubscribe(reporter, metric, datapoints)
    :exometer_report.subscribe(reporter, metric, datapoints, 10000)
  end

  def report_spiral(metric, value \\ 1),
    do: :exometer.update(metric, value)

  def report_histogram(metric, value),
    do: :exometer.update(metric, value)

  defp default_datapoints(:spiral),
    do: [:one, :count]
  defp default_datapoints(:histogram),
    do: [:mean, :min, :max, :median, 95, 99, 999]

  defp available_reporter() do
    case :exometer_report.list_reporters() do
      [] ->
        {:error, :no_reporters}
      [{one, _}] ->
        {:ok, one}
      _ ->
        {:error, :too_many_reporters}
    end
  end
end
