use Mix.Config

config :abacus_sql, ecto_repos: [
  AbacusSqlTest.Repo
]

config :abacus_sql, AbacusSqlTest.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "abacus-sql-test"


config :abacus_sql, :macro_module, AbacusSqlTest.MacroModule
