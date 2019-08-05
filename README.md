# AbacusSql

This library combines abacus and ecto. 

Pipe user-supplied abacus terms into queries like this:

```elixir
from(b in BlogPost) 
|> AbacusSql.where(~S[title == "abacus"])
|> AbacusSql.select("author", "author.name")
```

and you'll get a query that will not only filter for the posts title, but also automatically joins to the users table, adding the name of the author to the select list:

```
#Ecto.Query<from b in AbacusSqlTest.BlogPost, left_join: a in assoc(b, :author),
 where: b.title == ^"abacus", select: %{"author" => a.name}>
```

## Configuration

Allow additional type casts as such:

```elixir
config :abacus_sql, :allowed_casts, [
  :unit, :my_custom_type
]
```

These casts will be available as function calls: `unit("30 m")` and will be converted into a cast expression: `fragment("(?)::text::unit", type(^"30 m", :string))`.

Allow additional SQL functions:

```elixir
config :abacus_sql, :allowed_function_calls, [
  :extract, :coalesce, :st_buffer
]
```

These SQL functions will be available as normal function calls.

To add your own convert_ast clauses, configure a `macro_module`:

```elixir
config :abacus_sql, :macro_module, MyApp.MacroModule

defmodule MyApp.MacroModule do
  import AbacusSql.Term
  @spec convert_ast(any, Ecto.Query.t, list, integer) :: {any, Ecto.Query.t, list}
  # don't add a catch-all here, a FunctionClauseError on this function will automatically be handled gracefully
  def convert_ast({{"my_macro", _, nil}, ctx, args}, query, params, root_id) do
    {[arg0 | _rest], query, params} = reduce_args(args, query, params, root_id)
    ast = {:frament, ctx, [
      raw: "MY MACRO IS ",
      expr: arg0,
      raw: " YEAH"
    ]}
    {ast, query, params}
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `abacus_sql` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:abacus_sql, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/abacus_sql](https://hexdocs.pm/abacus_sql).

