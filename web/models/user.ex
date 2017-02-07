defmodule User.User do
  use User.Web, :model

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Poison.Encoder, only: [:email, :username, :inserted_at]}
  schema "users" do
    field :email, :string
    field :password, :string
    field :salt, :string
    field :username, :string

    timestamps()
  end

  def insert_changeset(struct, params \\ %{}) do
    struct
      |> cast(params, [:email, :password, :salt, :username])
      |> validate_required([:email, :password, :salt, :username])
      |> unique_constraint(:email)
      |> unique_constraint(:username)
  end
end
