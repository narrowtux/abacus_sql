defmodule AbacusSqlTest.User do
  use Ecto.Schema

  schema "user" do
    field :name, :string

    has_many :blog_posts, AbacusSqlTest.BlogPost, foreign_key: :author_id
  end
end
