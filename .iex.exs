alias AbacusSql.Term
alias AbacusSqlTest.{User, Repo, BlogPost}

if Mix.env == :test do
  Repo.start_link
end
import Ecto.Query
