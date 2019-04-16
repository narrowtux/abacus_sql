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
      {:abacus, github: "narrowtux/abacus", ref: "c8195d3b179d8a3ccefd01f4363f9e4afa418d71"},
      {:ecto, "~> 3.1"},
      {:ecto_sql, "~> 3.1", only: [:test]},
      {:postgrex, "~> 0.14.2", only: [:test]},
      {:jason, "~> 1.1"}
    ]
  end
end
