defmodule AbacusSql.UndefinedFunctionError do
  defexception [:function, :ctx, :argc]

  def exception(values) do
    struct(__MODULE__, Keyword.take(values, [:function, :ctx, :argc]))
  end

  def message(%__MODULE__{function: fun, argc: argc}) do
    "Call to undefined function \"#{fun}/#{argc}\""
  end
end
