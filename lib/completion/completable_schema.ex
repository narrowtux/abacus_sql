defmodule AbacusSql.Completable.Schema do
  alias AbacusSql.Completion.Item

  def children(schema, context, opts \\ []) do
    assocs =
      schema.__schema__(:associations)
      |> Enum.map(fn assoc ->
        details = schema.__schema__(:association, assoc)
        type = details.related
        %Item{
          code: to_string(assoc),
          type: type,
          display: schema.assoc_display(assoc, context),
          description: schema.assoc_description(assoc, context)
        }
      end)

    fields =
      schema.__schema__(:fields)
      |> Enum.map(fn field ->
        type = schema.__schema__(:type, field)
        %Item{
          code: to_string(field),
          type: type,
          display: schema.field_display(field, context),
          description: schema.field_description(field, context)
        }
      end)

    (assocs ++ fields)
    |> filter_only(Keyword.get(opts, :only, nil))
    |> filter_except(Keyword.get(opts, :except, nil))
  end

  defp filter_only(results, nil), do: results
  defp filter_only(results, only) do
    only = Enum.map(only, &to_string/1)
    Enum.filter(results, fn %{code: code} -> code in only end)
  end

  defp filter_except(results, nil), do: results
  defp filter_except(results, except) do
    except = Enum.map(except, &to_string/1)
    Enum.filter(results, fn %{code: code} -> code not in except end)
  end

  @callback assoc_description(assoc :: atom, context :: term) :: binary
  @callback assoc_display(assoc :: atom, context :: term) :: binary
  @callback field_description(field :: atom, context :: term) :: binary
  @callback field_display(field :: atom, context :: term) :: binary

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour AbacusSql.Completable

      def completable_children(context) do
        results = AbacusSql.Completable.Schema.children(__MODULE__, context, unquote(opts))
        {:ok, results, context}
      end

      def assoc_display(_, _), do: nil
      def assoc_description(_, _), do: nil
      def field_display(_, _), do: nil
      def field_description(_, _), do: nil

      defoverridable(assoc_display: 2, assoc_description: 2, field_display: 2, field_description: 2)
    end
  end
end
