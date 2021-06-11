defmodule AbacusSql do
  alias AbacusSql.Term
  @type t :: binary | list | tuple
  @type options :: [option]
  @type option :: root_option

  @moduledoc """
  Use AbacusSql to introduce powerful customizable query features to your application.

  By leveraging the safe to execute expression syntax of Abacus, Ecto queries can
  be modified with filters (via where/3), additional custom selects, custom order_by clauses,
  and more.

  ## Examples

      from(u in User, group_by: u.id)
      |> AbacuSql.where(~S[name == "Peter"]))
      |> AbacusSql.select("name", "name")
      # blog_posts assoc is automatically joined
      |> AbacusSql.select("post_count", "count(blog_posts.id)")
      |> AbacusSql.order_by("name", true)

      # take a filter from plug params
      from(u in User)
      |> where(Map.get(params, "filter", "true"))
  """

  @typedoc """
  Default: 0

  Specifies which source in the query should be used as root. It can either be
  given as a table id (0 is the actual root, 1-n is the first-nth join), or
  as an alias.

  The expressions will then have the given source as their root, meaning their
  fields and assocs are directly accessible.

  Example:

      query = from u in User, join bp in assoc(u, :blog_posts), as: :blog_posts
      AbacusSql.where(query, "title != null", root: :blog_posts)

  otherwise we'd have to write the where expression like this:

      query = from u in User, join bp in assoc(u, :blog_posts)
      AbacusSql.where(query, "blog_posts.title != null")
  """
  @type root_option :: {:root, integer() | atom()}

  @doc """
  Adds or merges a selection to the query.

  Example:

      query = from u in User
      query = select(query, "name", ~S[concat(name, " (", count(blog_posts.id), " posts)")])
      Repo.all(query) == [%{"name" => "Peter (31 posts)"}, %{"name" => "Mark (13 posts)"}]
  """
  @spec select(Ecto.Query.t, atom | String.t, t, options) :: Ecto.Query.t
  def select(query, key, term, opts \\ []) do
    params = case query.select do
      %{params: params} -> params
      _ -> []
    end
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, params, opts) do
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

  @doc """
  Adds an and_where clause to the query.
  """
  @spec where(Ecto.Query.t, t, options) :: Ecto.Query.t
  def where(query, term, opts \\ []) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, [], opts) do
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
  @spec having(Ecto.Query.t, t, options) :: Ecto.Query.t
  def having(query, term, opts \\ []) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, [], opts) do
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

  @doc """
  Adds an order_by expression to the query.
  """
  @spec order_by(Ecto.Query.t, t, boolean, options) :: Ecto.Query.t
  def order_by(query, term, ascending? \\ true, opts \\ []) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, [], opts) do
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

  @doc """
  Adds a group_by expression to the query
  """
  @spec group_by(Ecto.Query.t, t, options) :: Ecto.Query.t
  def group_by(query, term, opts \\ []) do
    with {:ok, query, expr, params} <- Term.to_ecto_term(query, term, [], opts) do
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

  @doc """
  Adds scoped data to the query. That data is accessible by simply accessing the given key.

  Example:

      from(u in User)
      |> AbacusSql.scope(:some_number, 13)
      |> AbacusSql.where("count(blog_posts.id) < some_number")
  """
  @spec scope(Ecto.Query.t(), atom(), term() | %{__struct__: module(), __meta__: Ecto.Schema.Metadata.t()}) :: Ecto.Query.t()
  def scope(query, key, value) do
    scope(query, [{key, value}])
  end

    @doc """
    Adds scoped data to the query. That data is accessible by simply accessing the given key.

    Example:

      from(u in User)
      |> AbacusSql.scope(some_number: 13)
      |> AbacusSql.where("count(blog_posts.id) < some_number")
  """
  @spec scope(Ecto.Query.t(), [{atom(), term() | %{__struct__: module(), __meta__: Ecto.Schema.Metadata.t()}}]) :: Ecto.Query.t()
  def scope(query, scope) do
    Enum.reduce(scope, query, fn {key, value}, query ->
      join = AbacusSql.Scope.scope_join(query, key, value)
      Map.update!(query, :joins, &(&1 ++ [join]))
    end)
  end
end
