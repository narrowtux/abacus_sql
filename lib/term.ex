defmodule AbacusSql.Term do
  defguardp is_primitive(term) when is_binary(term) or is_boolean(term) or is_number(term)

  @spec to_ecto_term(Ecto.Query.t, AbacusSql.t, list) :: {:ok, Ecto.Query.t, expr :: tuple, params :: list}
  def to_ecto_term(query, term, params \\ []) do
    {:ok, ast} = parse(term)

    {term_expr, query, params} = convert_ast(ast, query, params, get_root(query))

    {:ok, query, term_expr, Enum.reverse(params)}
  end

  @spec convert_ast(any, Ecto.Query.t, list, module) :: {any, Ecto.Query.t, list}
  def convert_ast(ast, query, params, root)
  def convert_ast({binary, _, nil}, query, params, root) when is_binary(binary) do
    {term, query, params, _root} = get_field(binary, query, params, root)
    {term, query, params}
  end

  def convert_ast({:., _, [from, {:variable, field}]}, query, params, root) do
    {_, query, params, root} = get_field(from, query, params, root)
    convert_ast({field, [], nil}, query, params, root)
  end

  def convert_ast(primitive, query, params, _root) when is_primitive(primitive) do
    term = {:^, [], [length(params)]}
    type = case primitive do
      t when is_binary(t) -> :string
      t when is_integer(t) -> :integer
      t when is_float(t) -> :float
      t when is_boolean(t) -> :boolean
    end
    params = [{primitive, type} | params]
    {term, query, params}
  end

  @ops ~w[== >= <= < > !=]a
  def convert_ast({ops, ctx, args}, query, params, root) when ops in @ops do
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

  def get_field(path, query, params, root)
  def get_field({field, _, nil}, query, params, root) when is_binary(field) do
    get_field(field, query, params, root)
  end
  def get_field(field, query, params, root) when is_binary(field) do
    root = root || get_root(query)
    root_id = get_table_id(query, root)

    {query, term, root} = case {find_field(root, field), find_assoc(root, field)} do
      {{field, _type}, nil} ->
        {query, {{:., [], [{:&, [], [root_id]}, field]}, [], []}, root}
      {nil, assoc} when is_atom(assoc) ->
        {query, tid} = auto_join(query, root_id, assoc)
        {query, nil, get_schema_by_id(query, tid)}
      {nil, nil} ->
        raise "could neither find #{field} as a field nor an association of #{root}"
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
    tid = length(query.joins) + 1
    query = Map.update!(query, :joins, &(&1 ++ [join]))
    {query, tid}
  end

  @spec find_field(atom, binary) :: {field :: atom, type :: atom} | nil
  def find_field(schema, name) do
    fields = schema.__schema__(:fields)
    case Enum.find(fields, &(to_string(&1) == name)) do
      nil ->
        nil
      field ->
        {field, schema.__schema__(:type, field)}
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
