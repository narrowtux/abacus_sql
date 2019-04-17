defmodule AbacusSqlTest.Comment do
  use Ecto.Schema
  use AbacusSql.Completable.Schema, only: [:blog_post, :author, :body, :inserted_at, :updated_at]
  schema "comment" do
    field :body, :string

    belongs_to :blog_post, AbacusSqlTest.BlogPost
    belongs_to :author, AbacusSqlTest.User
    timestamps()
  end

  def assoc_display(:blog_post, _) do
    "Blog post"
  end
  def assoc_display(:author, _) do
    "Author"
  end
  def assoc_description(:blog_post, _) do
    "Post that was commented on"
  end
  def assoc_description(:author, _) do
    "Author of the comment"
  end

  def field_display(:body, _) do
    "Body"
  end
  def field_display(:inserted_at, _) do
    "Created"
  end
  def field_display(:updated_at, _) do
    "Updated"
  end
  def field_description(:body, _) do
    "Text of the comment"
  end
  def field_description(:inserted_at, _) do
    "Creation datetime"
  end
  def field_description(:updated_at, _) do
    "Datetime of last update. If equal to inserted_at, it has not yet been updated"
  end
  def field_display(_, _) do
    nil
  end
  def assoc_display(_, _) do
    nil
  end
  def field_description(_, _) do
    nil
  end
  def assoc_description(_, _) do
    nil
  end
end
