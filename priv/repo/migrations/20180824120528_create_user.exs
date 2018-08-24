defmodule AbacusSqlTest.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:user) do
      add :name, :string

      timestamps()
    end

    alter table(:blog_post) do
      add :author_id, references(:user, on_delete: :delete_all)
    end
  end
end
