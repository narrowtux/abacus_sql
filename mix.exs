defmodule AbacusSql.MixProject do
  use Mix.Project

  def project do
    [
      app: :abacus_sql,
      version: "2.1.0",
      elixir: ">= 1.6.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Convert Abacus expression into Ecto DSL expressions, and use them for where, selects, order_by, group_by or having clauses.",
      package: package(),
      source_url: "https://github.com/narrowtux/abacus_sql"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/narrowtux/abacus_sql"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abacus, "~> 2.0"},
      {:ecto, "~> 3.6"},
      {:ecto_sql, "~> 3.6", only: [:test]},
      {:postgrex, "~> 0.15", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
