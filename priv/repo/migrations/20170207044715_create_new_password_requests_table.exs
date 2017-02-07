defmodule User.Repo.Migrations.CreateNewPasswordRequestsTable do
  use Ecto.Migration

  def change do
    create table(:new_password_requests) do
      add :user_id, :string
      add :reset_code, :string

      timestamps()
    end
  end
end
