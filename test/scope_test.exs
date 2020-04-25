defmodule AbacusSql.ScopeTest do
  use ExUnit.Case
  import Ecto.Query
  alias AbacusSqlTest.{BlogPost}

  test "virtual has_one assoc" do
    query =
      from(b in BlogPost)
      |> AbacusSql.scope(old_blog_post: %BlogPost{id: 13})
      |> AbacusSql.select("old_title", "old_blog_post.title")
      |> AbacusSql.select("new_title", "title")

    expected_query = from b in BlogPost,
      join: obp in BlogPost,
      on: obp.id == ^13,
      as: :old_blog_post,
      select: %{
        "old_title" => obp.title,
        "new_title" => b.title
      }

    assert inspect(query) == inspect(expected_query)
  end

  test "virtual scope data" do
    query =
      from(b in BlogPost)
      |> AbacusSql.scope(num: 13, bool: false, string: "ABC")
  end
end
