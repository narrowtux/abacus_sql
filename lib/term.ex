defmodule AbacusSql.Term do
  defguardp is_primitive(term) when is_binary(term) or is_boolean(term) or is_number(term)

  @spec to_ecto_term(Ecto.Query.t, AbacusSql.t, list) :: {:ok, Ecto.Query.t, expr :: tuple, params :: list}
  def to_ecto_term(query, term, params \\ []) do
    {:ok, ast} = parse(term)

    {term_expr, query, params} = convert_ast(ast, query, Enum.reverse(params), 0)

    {:ok, query, term_expr, Enum.reverse(params)}
  end

  @spec convert_ast(any, Ecto.Query.t, list, integer) :: {any, Ecto.Query.t, list}
  def convert_ast(ast, query, params, root)
  def convert_ast({binary, _, nil}, query, params, root) when is_binary(binary) do
    {term, query, params, _root} = get_field(binary, query, params, root)
    {term, query, params}
  end

  def convert_ast({ops, ctx, [l, r]}, query, params, root) when ops in ~w[== !=]a and (is_nil(r) or is_nil(l)) do
    fragment = case ops do
      :== -> " IS NULL"
      :!= -> " IS NOT NULL"
    end
    {literal, query, params} = case {l, r} do
      {nil, lit} -> convert_ast(lit, query, params, root)
      {lit, nil} -> convert_ast(lit, query, params, root)
    end
    expr = {:fragment, ctx, [
      raw: "",
      expr: literal,
      raw: fragment
    ]}
    {expr, query, params}
  end

  @allowed_fn_calls ~w[
    sum count avg min max
    date_trunc now
    like ilike
  ]a
  @allowed_fn_calls_bin Enum.map(@allowed_fn_calls, &to_string/1)
  def convert_ast({{fn_call, _, nil}, ctx, args}, query, params, root) when fn_call in @allowed_fn_calls_bin do
    {args, query, params} = reduce_args(args, query, params, root)
    case binary_to_allowed_atom(fn_call, @allowed_fn_calls) do
      nil ->
        raise "Function call #{fn_call} is not allowed"
      o ->
       term = {o, ctx, args}
       {term, query, params}
    end
  end

  @allowed_casts ~w[
    interval float text boolean
  ]
  def convert_ast({{cast, _, nil}, ctx, [arg]}, query, params, root) when cast in @allowed_casts do
    {arg, query, params} = convert_ast(arg, query, params, root)
    term = {:fragment, ctx, [
      raw: "(",
      expr: arg,
      raw: ")::text::" <> cast,
    ]}
    {term, query, params}
  end

  @binary_ops ~w[+ - * /]a
  def convert_ast({ops, ctx, args}, query, params, root) when ops in @binary_ops do
    {[lhs, rhs], query, params} = reduce_args(args, query, params, root)
    term = {:fragment, ctx, [
      raw: "",
      expr: lhs,
      raw: to_string(ops),
      expr: rhs,
      raw: ""
    ]}
    {term, query, params}
  end

  @bool_ops ~w[&& || not]a
  def convert_ast({ops, ctx, args}, query, params, root) when ops in @bool_ops do
    {args, query, params} = reduce_args(args, query, params, root)
    ops = case ops do
      :&& -> :and
      :|| -> :or
      :not -> :not
    end
    term = {ops, ctx, args}
    {term, query, params}
  end

  def convert_ast({:., _, [from, {:variable, field}]}, query, params, root) do
    {_, query, params, root} = get_field(from, query, params, root)
    convert_ast({field, [], nil}, query, params, root)
  end

  def convert_ast(primitive, query, params, _root) when is_primitive(primitive) do
    term = {:^, [], [length(params)]}
    type = typeof(primitive)
    params = [{primitive, type} | params]
    {term, query, params}
  end

  @compare_ops ~w[== >= <= < > !=]a
  def convert_ast({ops, ctx, args}, query, params, root) when ops in @compare_ops do
    {args, query, params} = reduce_args(args, query, params, root)
    term = {ops, ctx, args}
    {term, query, params}
  end

  @spec reduce_args(list(any), Ecto.Query.t, list, module) :: {list(any), Ecto.Query.t, list}
  def reduce_args(args, query, params, root) do
    {terms, {query, params}} = Enum.map_reduce(args, {query, params}, fn arg, {query, params} ->
      {term, query, params} = convert_ast(arg, query, params, root)
      {term, {query, params}}
    end)
    {terms, query, params}
  end

  # (((author.blog_posts).meta_tags).description)
  # join q.author a
  # join a.blog_posts bb
  # bb.meta_tags -> description

  def get_field(path, query, params, root)
  def get_field({:variable, name}, query, params, root) do
    get_field(name, query, params, root)
  end
  def get_field({:., _, [lhs, rhs]}, query, params, root) do
    {_, query, params, root} = get_field(lhs, query, params, root)
    get_field(rhs, query, params, root)
  end
  def get_field({field, _, nil}, query, params, root) when is_binary(field) do
    get_field(field, query, params, root)
  end
  def get_field(field, query, params, {root_field, :map}) do
    params = [{field, :string} | params]
    term = {:fragment, [], [
      raw: "",
      expr: root_field,
      raw: "->",
      expr: {:^, [], [length(params) - 1]},
      raw: ""
    ]}
    {term, query, params, {term, :map}}
  end
  def get_field(field, query, params, root_id) when is_binary(field) do
    root = get_schema_by_id(query, root_id)
    {query, term, root} = case {root, find_field(root, field), find_assoc(root, field)} do
      {_, nil, nil} ->
        raise "could neither find #{field} as a field nor an association of #{root}"
      {_, {field, type}, nil} ->
        term = {{:., [], [{:&, [], [root_id]}, field]}, [], []}
        {query, term, {term, type}}
      {_, nil, assoc} when is_atom(assoc)->
        {query, tid} = auto_join(query, root_id, assoc)
        {query, nil, tid}
    end

    {term, query, params, root}
  end

  @spec auto_join(Ecto.Query.t, origin_id :: integer, assoc :: atom) :: {Ecto.Query.t, table_id :: integer}
  def auto_join(query, origin_id, assoc) do
    join = %Ecto.Query.JoinExpr{
      assoc: {origin_id, assoc},
      qual: :left,
      on: %Ecto.Query.QueryExpr{expr: true},
      ix: nil,
      source: nil
    }
    case Enum.find_index(query.joins, fn
      %{assoc: {^origin_id, ^assoc}, qual: :left} -> true
      _ -> false
    end) do
      nil ->
        tid = length(query.joins) + 1
        query = Map.update!(query, :joins, &(&1 ++ [join]))
        {query, tid}
      tid when is_integer(tid) ->
        {query, tid + 1}
    end
  end

  @spec find_field(atom, binary) :: {field :: atom, type :: atom} | nil
  def find_field(schema, name) do
    fields = schema.__schema__(:fields)
    case Enum.find(fields, &(to_string(&1) == name)) do
      nil ->
        nil
      field ->
        type = schema.__schema__(:type, field)
        type = if function_exported?(type, :type, 0) do
          type.type()
        else
          type
        end
        {field, type}
    end
  end

  @spec find_assoc(atom, binary) :: assoc :: atom | nil
  def find_assoc(schema, name) do
    assocs = schema.__schema__(:associations)
    case Enum.find(assocs, &(to_string(&1) == name)) do
      nil -> nil
      assoc -> assoc
    end
  end

  @spec get_root(Ecto.Query.t) :: module
  def get_root(%{from: {_, module}}) when is_atom(module) do
    module
  end

  @spec get_table_id(Ecto.Query.t, module) :: integer
  def get_table_id(%{from: {_, module}}, module) do
    0
  end
  def get_table_id(%{joins: joins} = query, module) do
    case Enum.find_index(joins, &(get_join_source(query, &1) == module)) do
      nil -> raise "table_id for #{module} could not be found"
      int when is_integer(int) -> int + 1
    end
  end

  @spec get_schema_by_id(Ecto.Query.t, integer) :: module
  def get_schema_by_id(%{from: {_, schema}}, 0) when is_atom(schema) do
    schema
  end
  def get_schema_by_id(%{joins: joins} = query, id) do
    join = Enum.at(joins, id - 1)
    get_join_source(query, join)
  end

  def get_join_source(query, join) do
    case join do
      %{source: {_, schema}} when is_atom(schema) ->
        schema
      %{assoc: {origin_id, assoc}} ->
        origin_schema = get_schema_by_id(query, origin_id)
        origin_schema.__schema__(:association, assoc)
        |> Map.get(:queryable)
    end
  end

  def binary_to_allowed_atom(binary, atoms) do
    Enum.find(atoms, fn a -> to_string(a) == binary end)
  end

  def typeof(primitive) do
    case primitive do
      t when is_binary(t) -> :string
      t when is_integer(t) -> :integer
      t when is_float(t) -> :float
      t when is_boolean(t) -> :boolean
    end
  end

  @spec parse(AbacusSql.t) :: {:ok, tuple}
  def parse(ast) when is_tuple(ast) do
    ast
  end
  def parse(bin) do
    Process.put(:variables, %{})
    with bin <- to_string(bin),
         bin <- String.to_charlist(bin),
         {:ok, tokens, _} <- :math_term.string(bin),
         {:ok, ast} <- :new_parser.parse(tokens) do
      vars = Process.get(:variables)
      Process.delete(:variables)
      vars = Enum.map(vars, fn {k, v} -> {v, k} end) |> Enum.into(%{})
      ast = rename_variables(ast, vars)
      {:ok, ast}
    end
  end


  @spec rename_variables(tuple, map) :: tuple
  defp rename_variables(ast, vars) do
    Macro.prewalk(ast, fn
      {atom, ctx, nil} when is_atom(atom) ->
        case Map.get(vars, atom) do
          nil -> {atom, ctx, nil}
          s -> {s, ctx, nil}
        end
      o -> o
    end)
  end
end
