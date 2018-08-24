defmodule AbacusSqlTermTest do
  use ExUnit.Case
  doctest AbacusSql.Term

  test "parse" do
    assert {:ok, {:+, _, [{"a", _, nil}, {"b", _, nil}]}} = AbacusSql.Term.parse("a + b")
  end
end
