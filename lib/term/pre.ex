defmodule AbacusSql.Term.Pre do
  alias AbacusSql.Term

  @moduledoc """
  Some functions for preprocessing
  """

  def inject_schema(ast, query, params) do
    root = Term.get_root(query)

    {ast, _} = Macro.postwalk(ast, {root, query, params}, &_inject_schema/2)

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

    root = Term.get_root(query)

    ast = _inject_shortcut(ast, root, from_schema, from_ast, to_ast)

    {:ok, ast}
  end

  defp _inject_shortcut({:., ctx, [la, ra]} = ast, current_schema, from_schema, from_ast, to_ast) do
    left_schema = get_schema(la, current_schema)
    current_schema = get_schema(ast, current_schema)

    virtual_ra = case ra do
      {:variable, v} -> {v, [], nil}
      _ -> ra
    end
    found_left = current_schema == from_schema and ast_equals(la, from_ast)
    found_right = left_schema == from_schema and ast_equals(virtual_ra, from_ast)

    case {found_left, found_right} do
      {true, false} ->
        {:., ctx, [to_ast, ra]}
      {false, true} ->
        {:., ctx, [la, to_ast]}
      {true, true} ->
        # huh?
        ast
      {false, false} ->
        la = _inject_shortcut(la, current_schema, from_schema, from_ast, to_ast)
        {:., ctx, [la, ra]}
    end
  end
  defp _inject_shortcut({var, _, nil} = ast, current_schema, from_schema, from_ast, to_ast) when is_binary(var) do
    if current_schema == from_schema and ast_equals(ast, from_ast) do
      to_ast
    else
      ast
    end
  end
  defp _inject_shortcut({op, ctx, args}, current_schema, from_schema, from_ast, to_ast) do
    args = Enum.map(args, &_inject_shortcut(&1, current_schema, from_schema, from_ast, to_ast))
    {op, ctx, args}
  end
  defp _inject_shortcut(ast, _, _, _, _) do
    ast
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
