defmodule AbacusSqlTest.User do
  use Ecto.Schema
  use AbacusSql.Completable.Schema

  schema "user" do
    field :name, :string

    has_many :blog_posts, AbacusSqlTest.BlogPost, foreign_key: :author_id
    has_many :comments, AbacusSqlTest.Comment, foreign_key: :author_id
  end
end
