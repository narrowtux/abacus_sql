defmodule AbacusSqlTest.BlogPost do
  use Ecto.Schema

  schema "blog_post" do
    field :title, :string
    field :body, :string

    belongs_to :author, AbacusSqlTest.User
    has_many :comments, AbacusSqlTest.Comment

    timestamps()
  end
end
