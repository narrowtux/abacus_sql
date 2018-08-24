defmodule AbacusSql do
  alias AbacusSql.Term
  @type t :: binary | list | tuple

  @spec select(Ecto.Query.t, atom, t) :: Ecto.Query.t
  def select(query, key, term) do
    params = case query.select do
      %{params: params} -> params
      _ -> []
    end
    {:ok, query, expr, params} = Term.to_ecto_term(query, term, params)
    select_item = {key, expr}

    new_select = %Ecto.Query.SelectExpr{
      expr: {:%{}, [], [select_item]},
      params: params,
      take: %{}
    }
    Map.update(query, :select, new_select, fn
      nil ->
        new_select
      %Ecto.Query.SelectExpr{
        expr: {:%{}, ctx, list},
        params: _
      } = select ->
        select
        |> Map.put(:expr, {:%{}, ctx, list ++ [select_item]})
        |> Map.put(:params, params)
    end)
  end

  @spec where(Ecto.Query.t, t) :: Ecto.Query.t
  def where(query, term) do
    {:ok, query, expr, params} = Term.to_ecto_term(query, term)
    where = %Ecto.Query.BooleanExpr{
      expr: expr,
      op: :and,
      params: params
    }
    query
    |> Map.update!(:wheres, &[where | &1])
  end

  # @spec order_by(Ecto.Query.t, t, boolean) :: Ecto.Query.t
  # def order_by(query, term, ascending? \\ true) do
  #   {:ok, query, expr, params} = Term.to_ecto_term(query, term)

  #   query
  # end

  # @spec group_by(Ecto.Query.t, t) :: Ecto.Query.t
  # def group_by(query, term) do
  #   {:ok, query, expr, params} = Term.to_ecto_term(query, term)

  #   query
  # end
end
