defmodule AbacusSqlTermTest do
  use ExUnit.Case
  doctest AbacusSql.Term
  alias AbacusSql.Term

  import Ecto.Query
  alias AbacusSqlTest.{BlogPost}

  test "parse" do
    assert {:ok, {:+, _, [{"a", _, nil}, {"b", _, nil}]}} = AbacusSql.Term.parse("a + b")
  end

  test "get root from query" do
    sub_query = from q in BlogPost, where: q.title == type(^"Abacus is cool", :string)
    query = from(x in subquery(sub_query))

    assert AbacusSqlTest.BlogPost == Term.get_root(sub_query)
    assert AbacusSqlTest.BlogPost == Term.get_root(query)
  end

end
