defmodule AbacusSqlTest.BlogPost do
  use Ecto.Schema
  use AbacusSql.Completable.Schema

  schema "blog_post" do
    field :title, :string
    field :body, :string

    field :meta_tags, :map

    belongs_to :author, AbacusSqlTest.User
    has_many :comments, AbacusSqlTest.Comment
    has_one :fields, __MODULE__.Fields

    timestamps()
  end

  defmodule Fields do
    use Ecto.Schema

    schema "fields" do
      belongs_to :blog_post, AbacusSqlTest.BlogPost, foreign_key: :blog_post_id
      field :data, :map
    end
  end
end
