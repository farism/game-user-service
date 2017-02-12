defmodule User.Repo.Migrations.AddUserActiveField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active, :boolean, default: false
    end
  end
end
