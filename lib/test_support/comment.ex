defmodule AbacusSqlTest.Comment do
  use Ecto.Schema
  schema "comment" do
    field :body, :string

    belongs_to :blog_post, AbacusSqlTest.BlogPost
    belongs_to :author, AbacusSqlTest.User
    timestamps()
  end
end
