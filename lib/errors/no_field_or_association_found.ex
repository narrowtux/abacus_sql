defmodule AbacusSql.NoFieldOrAssociationFoundError do
  defexception [:name, :in, :ctx]

  def exception(value) do
    struct(__MODULE__, Keyword.take(value, [:name, :in, :ctx]))
  end

  def message(%__MODULE__{in: schema, name: name}) do
    schema =
      schema
      |> to_string()
      |> String.replace_leading("Elixir.", "")

    "\"#{name}\" was neither found as a field nor as an association of #{schema}"
  end
end
