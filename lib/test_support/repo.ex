if Mix.env == :test do
  defmodule AbacusSqlTest.Repo do
    use Ecto.Repo, otp_app: :abacus_sql
  end
end

