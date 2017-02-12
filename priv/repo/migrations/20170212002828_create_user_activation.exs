defmodule User.Repo.Migrations.CreateUserActivation do
  use Ecto.Migration

  def change do
    create table(:user_activations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :string

      timestamps()
    end
  end
end
