defmodule AbacusSql.Completion do
  @dot_autocomplete ~r/([a-z0-9\._]*)\.$/
  @filtered_with_dot ~r/([a-z0-9\._]*)\.([a-z0-9_]+)$/
  @filtered_without_dot ~r/([a-z0-9_]*)$/

  @type context :: [{atom, any}]
  @type schema :: module | {module, context}

  @spec autocomplete(binary, module, any) :: {:ok, [AbacusSql.Completion.Item.t]} | {:error, any}
  def autocomplete(code, root_schema, context \\ []) do
    with {:ok, {expression, filter}} <- filter_code(code),
         {:ok, deepest_schema} <- find_deepest_schema(expression, root_schema, context),
         {deepest_schema, context} <- extract_schema_context(deepest_schema, context),
         {:ok, results, _context} <- AbacusSql.Completable.children(deepest_schema, context),
         {:ok, filtered_results} <- filter_results(results, filter) do
      {:ok, filtered_results}
    else
      e ->
        {:error, e}
    end
  end

  @spec filter_code(code :: binary) :: {:ok, {expression :: binary, filter :: binary}} | {:error, any}
  defp filter_code(code) do
    with :error <- dot_autocomplete(code),
         :error <- filtered_with_dot(code),
         :error <- filtered_without_dot(code) do
      {:error, :not_completable}
    else
      {:ok, _result} = ok -> ok
    end
  end

  defp dot_autocomplete(code) do
    case Regex.run(@dot_autocomplete, code) do
      [_, ""] -> :error
      nil -> :error
      [_, expression] -> {:ok, {expression, nil}}
    end
  end

  defp filtered_with_dot(code) do
    case Regex.run(@filtered_with_dot, code) do
      nil -> :error
      [_, "", _] -> :error
      [_, _, ""] -> :error
      [_, expression, filter] -> {:ok, {expression, filter}}
    end
  end

  defp filtered_without_dot(code) do
    case Regex.run(@filtered_without_dot, code) do
      [_, ""] -> {:ok, {nil, nil}}
      nil -> :error
      [_, filter] -> {:ok, {nil, filter}}
    end
  end

  @spec find_deepest_schema(expr :: binary | tuple, module, term) :: {:ok, module} | {:error, term}
  defp find_deepest_schema(nothing, root_schema, _context) when is_nil(nothing) or nothing == "", do: {:ok, root_schema}
  defp find_deepest_schema(expr, root_schema, context) when is_binary(expr) do
    with {:ok, ast} <- AbacusSql.Term.parse(expr) do
      find_deepest_schema(ast, root_schema, context)
    else
      _ -> {:error, :compile_error}
    end
  end
  defp find_deepest_schema({variable, _, nil}, root_schema, context) do
    # single variable was used
    with {:ok, result, context} <- find_single_result_in_schema(root_schema, variable, context),
         {schema, context} <- extract_schema_context(result.type, context) do
      {:ok, {schema, context}}
    end
  end
  defp find_deepest_schema({:., _, [{up, _, nil}, down]}, root_schema, context) do
    find_deepest_schema({:., [], [up, {:variable, down}]}, root_schema, context)
  end
  defp find_deepest_schema({:., _, [up, {:variable, down}]}, root_schema, context) do
    with {:ok, up_schema} <- find_deepest_schema(up, root_schema, context) do
      find_deepest_schema({down, [], nil}, up_schema, context)
    end
  end
  defp find_deepest_schema(expr, module, term) do
    {:error, :invalid_path}
  end

  @spec find_single_result_in_schema(schema, any(), context) ::
          {:error, any} | {:ok, module, context}
  def find_single_result_in_schema(schema, variable, context) do
    {schema, context} = extract_schema_context(schema, context)
    with {:ok, results, context} <- AbacusSql.Completable.children(schema, context),
         [result] <- Enum.filter(results, &(&1.code == variable)) do
      {:ok, result, context}
    else
      _ ->
        {:error, :invalid_path}
    end
  end

  @spec extract_schema_context(schema, context) :: {module, context}
  def extract_schema_context(schema, context) when is_atom(schema) and is_list(context) do
    {schema, context}
  end
  def extract_schema_context({schema, schema_context}, context) when is_atom(schema) and is_list(schema_context) do
    {schema, Keyword.merge(context, schema_context)}
  end

  defp filter_results(results, nothing) when is_nil(nothing) or nothing == "" do
    results = Enum.map(results, &Map.put(&1, :filtered_code, &1.code))
    {:ok, results}
  end
  defp filter_results(results, filter) do
    results =
      results
      |> Enum.filter(&String.starts_with?(&1.code, filter))
      |> Enum.map(fn item ->
        filtered_code = String.replace_leading(item.code, filter, "")
        Map.put(item, :filtered_code, filtered_code)
      end)

    {:ok, results}
  end
end
