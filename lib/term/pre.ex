defmodule AbacusSql.Term.Pre do
  alias AbacusSql.Term

  @moduledoc """
  Some functions for preprocessing
  """

  def inject_schema(ast, query, params) do
    root = Term.get_root(query)

    {ast, _} = Macro.prewalk(ast, {root, query, params}, &_inject_schema/2)

    IO.inspect ast

    {:ok, ast}
  end

  def _inject_schema(ast, {nil, _, _} = acc) do
    {ast, acc}
  end
  def _inject_schema({:., ctx, [left, right]}, {root, query, params}) do
    root_id = Term.get_table_id(query, root)

    {query, params, root, root_id} = get_schema_from_field(left, query, params, root, root_id)
    {query, params, root, _root_id} = get_schema_from_field(right, query, params, root, root_id)

    ctx = Keyword.put(ctx, :schema, root)
    ast = {:., ctx, [left, right]}

    {ast, {root, query, params}}
  end
  def _inject_schema({varname, ctx, nil} = ast, {root, query, params}) when is_binary(varname) do
    root_id = Term.get_table_id(query, root)
    {query, params, root, _root_id} = get_schema_from_field(ast, query, params, root, root_id)
    ctx = Keyword.put(ctx, :schema, root)
    ast = {varname, ctx, nil}
    {ast, {root, query, params}}
  end

  def _inject_schema(ast, {_, _, _} = acc) do
    {ast, acc}
  end

  defp get_schema_from_field(ast, query, params, root, root_id) do
    try do
      {_, query, params, root_id} = Term.get_field(ast, query, params, root_id)
      root = root_from_id(query, root_id, root)
      {query, params, root, root_id}
    rescue
      _ -> {query, params, root, root_id}
    catch
      _ -> {query, params, root, root_id}
    end
  end

  defp root_from_id(query, id, prev_root) do
    case id do
      int when is_integer(int) -> Term.get_schema_by_id(query, int)
      _ -> prev_root
    end
  end

  def shortcut(schema, from, to) do
    {:ok, from_ast} = Term.parse(from)
    {:ok, to_ast} = Term.parse(to)

    &inject_shortcut(&1, &2, &3, schema, from_ast, to_ast)
  end

  def inject_shortcut(ast, query, params, from_schema, from_ast, to_ast) do
    {:ok, to_ast} = inject_schema(to_ast, query, params)
    {ast, _} = Macro.prewalk(ast, from_schema, &_inject_shortcut(&1, &2, from_schema, from_ast, to_ast))

    {:ok, ast}
  end

  def _inject_shortcut(ast, current_schema, from_schema, from_ast, to_ast) do
    if ast_equals(ast, from_ast) and current_schema == from_schema do
      {to_ast, current_schema}
    else
      {ast, get_schema(ast, current_schema)}
    end
  end

  defp get_schema({_, ctx, _}, default) do
    Keyword.get(ctx, :schema, default)
  end
  defp get_schema(_, default) do
    default
  end

  defp ast_equals({lf, _, la}, {rf, _, ra}) do
    lf == rf and args_equal(la, ra)
  end
  defp ast_equals(same, same) do
    true
  end
  defp ast_equals(_, _) do
    false
  end

  defp args_equal(la, ra)
  defp args_equal(nil, nil), do: true
  defp args_equal(la, ra) when is_nil(la) or is_nil(ra), do: false
  defp args_equal(la, ra) when length(la) != length(ra), do: false
  defp args_equal(la, ra) when is_list(la) and is_list(ra) do
    Enum.zip(la, ra)
    |> Enum.all?(fn {l, r} -> ast_equals(l, r) end)
  end
end
