defmodule Loader.MixProject do
  use Mix.Project

  def project do
    [
      app: :loader,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Loader.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:exometer_core, "~> 1.5.0", override: true},
      {:exometer_report_graphite, git: "https://github.com/esl/exometer_report_graphite.git", branch: "master"},
      {:meck, "~> 0.8.13", override: true},
      {:escalus, git: "https://github.com/esl/escalus.git", tag: "4.0.0"},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 4.0"},
      {:recon, "~> 2.5"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
