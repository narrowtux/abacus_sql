defmodule AbacusSql.CompletionTest do
  use ExUnit.Case

  test "dot-autocompletion" do
    code = "36 * 10 * (blog_posts."
    root_schema = AbacusSqlTest.User
    assert {:ok, results} = AbacusSql.Completion.autocomplete(code, root_schema)
    assert 10 == length(results)
  end

  test "filtered autocompletion" do
    code = "36 * 10 * (blog_posts.c"
    root_schema = AbacusSqlTest.User
    assert {:ok, results} = AbacusSql.Completion.autocomplete(code, root_schema)
    assert 1 == length(results)
    assert [%{code: "comments", filtered_code: "omments"}] = results
  end

  test "root schema autocompletion" do
    code = "36 * 10 * ("
    root_schema = AbacusSqlTest.User
    assert {:ok, results} = AbacusSql.Completion.autocomplete(code, root_schema)
    assert 4 == length(results)
  end
end
