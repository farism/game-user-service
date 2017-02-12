defmodule User.User do
  use User.Web, :model

  @required_fields [:email, :password, :salt, :username]
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Poison.Encoder, only: [:email, :username, :inserted_at]}

  schema "users" do
    field :email, :string
    field :password, :string
    field :salt, :string
    field :username, :string
    field :active, :boolean, default: false

    timestamps()
  end


  def changeset(struct, params \\ %{}) do
    struct
      |> cast(params, @required_fields)
      |> validate_required(@required_fields)
      |> unique_constraint(:email)
      |> unique_constraint(:username)
  end
end
