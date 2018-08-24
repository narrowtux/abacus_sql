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

  test "no duplicate joins" do
    origin_query = from q in BlogPost,
      left_join: a in assoc(q, :author)

    expected_query = from [b, a] in origin_query,
      where: a.name == ^"Blabla"

    query = AbacusSql.where(origin_query, ~S[author.name == "Blabla"])

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

  test "auto-join 2 deep" do
    expected_query =
      from b in BlogPost,
        left_join: c in assoc(b, :comments),
        left_join: a in assoc(c, :author),
        where: a.name == ^"Moritz Schmale"

    query =
      from(b in BlogPost)
      |> AbacusSql.where(~S[comments.author.name == "Moritz Schmale"])

    assert inspect(expected_query) == inspect(query)
  end

  test "auto-join 3 deep" do
    expected_query =
      from b in BlogPost,
        left_join: c in assoc(b, :comments),
        left_join: a in assoc(c, :author),
        left_join: bb in assoc(a, :blog_posts),
        where: bb.title == ^"abacus"

    query =
      from(b in BlogPost)
      |> AbacusSql.where(~S[comments.author.blog_posts.title == "abacus"])

    assert inspect(expected_query) == inspect(query)
  end

  test "order by" do
    expected_query =
      from b in BlogPost,
        left_join: a in assoc(b, :author),
        order_by: a.name

    query =
      from(b in BlogPost)
      |> AbacusSql.order_by("author.name")

    assert inspect(expected_query) == inspect(query)
  end

  test "group by" do
    expected_query =
      from b in BlogPost,
        group_by: b.author_id

    query =
      from(b in BlogPost)
      |> AbacusSql.group_by("author_id")

    assert inspect(expected_query) == inspect(query)
  end
end
