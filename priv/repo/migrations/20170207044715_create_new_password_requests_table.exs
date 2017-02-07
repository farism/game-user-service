defmodule User.Repo.Migrations.CreateNewPasswordRequestsTable do
  use Ecto.Migration

  def change do
    create table(:new_password_requests, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :string

      timestamps()
    end
  end
end
