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
    # {:ok, to_ast} = Term.parse(to)

    &inject_shortcut(&1, &2, &3, schema, from_ast, to)
  end

  def inject_shortcut(ast, query, params, from_schema, from_ast, replacement) do
    deep_replace = fn parent ->
      parent = format_access(parent)
      "#{parent}.#{replacement}"
    end
    deep_ast = Macro.postwalk(from_ast, fn
      {var, _, nil} ->
        {:., [schema: from_schema], [{"_", [], nil}, var]}
      ast -> ast
    end)
    with {:ok, ast} <- inject_macro(ast, query, params, from_schema, from_ast, fn -> replacement end),
         {:ok, ast} <- inject_macro(ast, query, params, from_schema, deep_ast, deep_replace) do
      {:ok, ast}
    end
  end

  def macro(schema, pattern, replacer) do
    {:ok, pattern_ast} = Term.parse(pattern)

    &inject_macro(&1, &2, &3, schema, pattern_ast, replacer)
  end

  def inject_macro(ast, _query, _params, schema, pattern_ast, replacer) do
    ast = Macro.prewalk(ast, fn
      {_, ctx, _} = original_ast ->
        with ^schema <- Keyword.get(ctx, :schema),
          {:matches, args} <- pattern_match_ast(original_ast, pattern_ast),
          formula <- apply(replacer, args),
          {:ok, ast} <- Term.parse(formula) do
          ast
        else
          _ ->
            original_ast
        end
      ast ->
        ast
    end)

    {:ok, ast}
  end

  def pattern_match(formula, pattern) do
    with {:ok, ast} <- Term.parse(formula),
         {:ok, pattern} <- Term.parse(pattern) do
      pattern_match_ast(ast, pattern)
    end
  end

  def pattern_match_ast(ast, pattern, matches \\ [])
  def pattern_match_ast({fun, _, args}, {pfun, _, pargs}, matches) do
    cond do
      fun == pfun -> reduce_pattern_match_args(args, pargs, matches)
      is_placeholder?(pfun) -> reduce_pattern_match_args(args, pargs, matches ++ [fun])
      true -> :nomatch
    end
  end
  def pattern_match_ast(ast, pattern, matches) do
    cond do
      is_placeholder?(pattern) -> {:matches, matches ++ [ast]}
      ast_equals(ast, pattern) -> {:matches, matches}
      true -> :nomatch
    end
  end

  def reduce_pattern_match_args(same, same, matches) do
    {:matches, matches}
  end
  def reduce_pattern_match_args(args, pargs, matches) when length(args) == length(pargs) do
    args
    |> Enum.zip(pargs)
    |> Enum.reduce_while(matches, fn {arg, parg}, matches ->
      cond do
        arg == parg -> {:cont, matches}
        ast_equals(arg, parg) -> {:cont, matches}
        is_placeholder?(parg) -> {:cont, matches ++ [arg]}
        true -> case pattern_match_ast(arg, parg, matches) do
          {:matches, matches} -> {:cont, matches}
          :nomatch -> {:halt, nil}
        end
      end
    end)
    |> case do
      nil -> :nomatch
      matches -> {:matches, matches}
    end
  end
  def reduce_pattern_match_args(_, _, _), do: :nomatch

  def is_placeholder?({"_", _, nil}), do: true
  def is_placeholder?("_"), do: true
  def is_placeholder?(_), do: false

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

  def format_access({:., _, [parent, child]}) when is_binary(child) do
    "#{format_access(parent)}.#{child}"
  end
  def format_access({variable, _, nil}) do
    variable
  end
  def format_access({:., _, [parent, child]}) do
    "#{format_access(parent)}[#{child}]"
  end
end
