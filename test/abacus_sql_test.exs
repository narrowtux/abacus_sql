defmodule AbacusSqlTest do
  use ExUnit.Case
  doctest AbacusSql

  import Ecto.Query
  alias AbacusSqlTest.{BlogPost, User}

  setup do
    Application.put_env(:abacus_sql, :preprocessors, [
      AbacusSql.Term.Pre.shortcut(BlogPost, "authors_posts", "author.blog_posts"),
      AbacusSql.Term.Pre.shortcut(BlogPost, "commenters", "comments.author")
    ])
  end

  test "where" do
    expected_query = from q in BlogPost,
      where: q.title == type(^"Abacus is cool", :string)

    query =
      from(q in BlogPost)
      |> AbacusSql.where(~S[title == "Abacus is cool"])

    assert inspect(expected_query) == inspect(query)
  end

  test "where from subquery" do

    base_query = from q in BlogPost
    expected_query = from x in subquery(base_query), where: x.title == type(^"Abacus is cool", :string)

    query = from(y in subquery(
      from(q in BlogPost)
    ))
    |> AbacusSql.where(~S[title == "Abacus is cool"])

    assert inspect(expected_query) == inspect(query)
  end

  test "where with auto join" do
    expected_query = from q in BlogPost,
      left_join: a in assoc(q, :author),
      where: a.name == type(^"Moritz Schmale", :string)

    query =
      from(q in BlogPost)
      |> AbacusSql.where(~S[author.name == "Moritz Schmale"])

    assert inspect(expected_query) == inspect(query)
  end

  test "no duplicate joins" do
    origin_query = from q in BlogPost,
      left_join: a in assoc(q, :author)

    expected_query = from [b, a] in origin_query,
      where: a.name == type(^"Blabla", :string)

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
        where: a.name == type(^"Moritz Schmale", :string)

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
        where: bb.title == type(^"abacus", :string)

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

  test "ternary if" do
    expected_query =
      from ba in User,
        left_join: bp in assoc(ba, :blog_posts),
        group_by: bp.id,
        select: %{
          "posts" => fragment(
            "CASE WHEN ? THEN ? ELSE ? END",
            count(bp.id) > type(^0, :integer),
            fragment("(?)::text::text", count(bp.id)),
            type(^"none", :string)
          )
        }

    query =
      from(u in User)
      |> AbacusSql.group_by("blog_posts.id")
      |> AbacusSql.select("posts", "count(blog_posts.id) > 0 ? text(count(blog_posts.id)) : \"none\"")

    assert inspect(expected_query) == inspect(query)
  end
end
