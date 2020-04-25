defmodule AbacusSql.Scope do
  def scope_join(query, key, %{__meta__: %Ecto.Schema.Metadata{}, __struct__: schema} = struct) do
    source_index = length(query.joins) + 1

    primary_keys =
      schema.__schema__(:primary_key)
      |> Enum.map(fn field ->
        %{
          key: field,
          value: Map.get(struct, field),
          type: schema.__schema__(:type, field)
        }
      end)

    {params, exprs} = Enum.reduce(primary_keys, {[], []}, fn %{key: field, value: value, type: type}, {params, exprs} ->
      param_index = length(params)
      params = params ++ [{value, type}]

      expr = {:==, [], [
        {
          {:., [], [{:&, [], [source_index]}, field]},
          [],
          []
        },
        {:^, [], [param_index]}
      ]}
      exprs = exprs ++ [expr]
      {params, exprs}
    end)

    expr = AbacusSql.AstUtil.join_right_operator(exprs, :and)

    %Ecto.Query.JoinExpr{
      as: key,
      qual: :inner,
      on: %Ecto.Query.QueryExpr{
        params: params,
        expr: expr
      },
      source: {nil, schema}
    }
  end

  def scope_join(_query, key, value) do
    type = AbacusSql.Term.typeof(value)

    %Ecto.Query.JoinExpr{
      as: key,
      qual: :inner,
      on: %Ecto.Query.QueryExpr{expr: true},
      params: [{value, type}],
      source: {:fragment, [], [
        raw: "(SELECT ",
        expr: {:type, [], [{:^, [], [0]}, type]},
        raw: " AS d)"
      ]}
    }
  end
end
