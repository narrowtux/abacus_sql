defmodule AbacusSql do
  alias AbacusSql.Term
  @type t :: binary | list | tuple

  @spec select(Ecto.Query.t, atom | String.t, t) :: Ecto.Query.t
  def select(query, key, term) do
    params = case query.select do
      %{params: params} -> params
      _ -> []
    end
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, params) do
      select_item = {key, expr}
      select_expr = {:%{}, [], [select_item]}

      new_select = %Ecto.Query.SelectExpr{
        expr: select_expr,
        params: params,
        take: %{}
      }
      Map.update(query, :select, new_select, fn
        nil ->
          new_select

        %Ecto.Query.SelectExpr{
          expr: {:%{}, ctx, list}
        } = select ->
          select
          |> Map.put(:expr, {:%{}, ctx, list ++ [select_item]})
          |> Map.put(:params, params)

        %Ecto.Query.SelectExpr{
          expr: {:merge, ctx, _} = merge
        } = select ->
          select
          |> Map.put(:expr, {:merge, [], [merge, select_expr]})
          |> Map.put(:params, params)
      end)
    else
      _ -> query
    end
  end

  @spec where(Ecto.Query.t, t) :: Ecto.Query.t
  def where(query, term) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term) do
      where = %Ecto.Query.BooleanExpr{
        expr: expr,
        op: :and,
        params: params
      }
      Map.update!(query, :wheres, &[where | &1])
    else
      _ -> query
    end
  end

  @doc """
  Adds the given filter to the havings list.

  Make sure that the query has at least one group_by clause.

  The advantage is that it can filter inside `has_many` assocs
  using aggregation such as `count`, `min` or `max`.

  For example: `having(BlogPost, "count(author.posts.id) > 10")` would
  filter for blog posts whose authors have at least 10 posts.
  """
  @spec having(Ecto.Query.t, t) :: Ecto.Query.t
  def having(query, term) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term) do
      having = %Ecto.Query.BooleanExpr{
        expr: expr,
        op: :and,
        params: params
      }
      Map.update!(query, :havings, &[having | &1])
    else
      _ -> query
    end
  end

  @spec order_by(Ecto.Query.t, t, boolean) :: Ecto.Query.t
  def order_by(query, term, ascending? \\ true) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term) do
      direction = if ascending?, do: :asc, else: :desc

      Map.update!(query, :order_bys, fn order_bys ->
        order_by = %Ecto.Query.QueryExpr{
          expr: [{direction, expr}],
          params: params
        }
        order_bys ++ [order_by]
      end)
    else
      _ -> query
    end
  end

  @spec group_by(Ecto.Query.t, t) :: Ecto.Query.t
  def group_by(query, term) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term) do
      Map.update!(query, :group_bys, fn group_bys ->
        group_by = %Ecto.Query.QueryExpr{
          expr: [expr],
          params: params
        }
        group_bys ++ [group_by]
      end)
    else
      _ -> query
    end
  end
end
