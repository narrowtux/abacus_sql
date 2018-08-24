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

