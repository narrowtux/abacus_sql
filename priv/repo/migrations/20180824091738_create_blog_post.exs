defmodule AbacusSqlTest.Repo.Migrations.CreateBlogPost do
  use Ecto.Migration

  def change do
    create table("blog_post") do
      add :title, :string
      add :body, :text

      timestamps()
    end
  end
end
