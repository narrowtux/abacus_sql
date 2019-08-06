defmodule AbacusSqlTest.MacroTest do
  use ExUnit.Case
  alias AbacusSqlTest.{BlogPost}
  import Ecto.Query

  setup do
    Application.put_env(:abacus_sql, :preprocessors, [
      AbacusSql.Term.Pre.macro(BlogPost.Fields, "fields.data._", &"date_trunc(fields.data, \"#{&1}\")")
    ])
  end

  test "macro" do
    base_query = from b in BlogPost
    actual_query = AbacusSql.where(base_query, "fields.data.foobar")

    assert "#Ecto.Query<from b0 in AbacusSqlTest.BlogPost, left_join: f1 in assoc(b0, :fields), where: date_trunc(f1.data, type(^\"foobar\", :string))>" == inspect(actual_query)
  end
end
