defmodule ShortcutTest do
  use ExUnit.Case

  import Ecto.Query
  alias AbacusSqlTest.{BlogPost}

  test "shortcut" do
    Application.put_env(:abacus_sql, :preprocessors, [
      AbacusSql.Term.Pre.shortcut(BlogPost, "authors_posts", "author.blog_posts")
    ])

    query = AbacusSql.select(from(b in BlogPost), "post_title", "authors_posts.title")

    expected_query = from b in BlogPost,
      left_join: u in assoc(b, :author),
      left_join: b2 in assoc(u, :blog_posts),
      select: %{
        "post_title" => b2.title
      }

    assert inspect(expected_query) == inspect(query)
  end
end
