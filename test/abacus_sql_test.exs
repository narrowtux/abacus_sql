defmodule AbacusSqlTest do
  use ExUnit.Case
  doctest AbacusSql

  import Ecto.Query
  alias AbacusSqlTest.{BlogPost}

  test "where" do
    expected_query = from q in BlogPost,
      where: q.title == ^"Abacus is cool"

    query =
      from(q in BlogPost)
      |> AbacusSql.where(~S[title == "Abacus is cool"])

    assert inspect(expected_query) == inspect(query)
  end

  test "where with auto join" do
    expected_query = from q in BlogPost,
      left_join: a in assoc(q, :author),
      where: a.name == ^"Moritz Schmale"

    query =
      from(q in BlogPost)
      |> AbacusSql.where(~S[author.name == "Moritz Schmale"])

    assert inspect(expected_query) == inspect(query)
  end

  test "custom select" do
    expected_query = from q in BlogPost,
      select: %{"custom" => q.title}

    query =
      from(q in BlogPost)
      |> AbacusSql.select("custom", "title")

    assert inspect(expected_query) == inspect(query)
  end
end
