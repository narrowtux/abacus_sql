defmodule AbacusSql.MixProject do
  use Mix.Project

  def project do
    [
      app: :abacus_sql,
      version: "0.1.0",
      elixir: ">= 1.6.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abacus, github: "narrowtux/abacus", ref: "b23be98d937ae2968a152e5d38910b4e439be91e"},
      {:ecto, "~> 3.1"},
      {:ecto_sql, "~> 3.1", only: [:test]},
      {:postgrex, "~> 0.14.2", only: [:test]},
      {:jason, "~> 1.1"}
    ]
  end
end
