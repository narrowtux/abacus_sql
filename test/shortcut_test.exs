defmodule ShortcutTest do
  use ExUnit.Case

  import Ecto.Query
  alias AbacusSqlTest.{BlogPost, User}

  setup do
    Application.put_env(:abacus_sql, :preprocessors, [
      AbacusSql.Term.Pre.shortcut(BlogPost, "authors_posts", "author.blog_posts"),
      AbacusSql.Term.Pre.shortcut(BlogPost, "commenters", "comments.author")
    ])
  end

  test "shortcut" do
    query = AbacusSql.select(from(b in BlogPost), "post_title", "authors_posts.title")

    expected_query = from b in BlogPost,
      left_join: u in assoc(b, :author),
      left_join: b2 in assoc(u, :blog_posts),
      select: %{
        "post_title" => b2.title
      }

    assert inspect(expected_query) == inspect(query)
  end

  test "shortcut deeper" do
    query = AbacusSql.select(from(u in User), "commenter", "blog_posts.commenters.name")

    expected_query = from u in User,
      left_join: b in assoc(u, :blog_posts),
      left_join: c in assoc(b, :comments),
      left_join: a in assoc(c, :author),
      select: %{
        "commenter" => a.name
      }

    assert inspect(expected_query) == inspect(query)
  end
end
