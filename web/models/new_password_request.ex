defmodule User.NewPasswordRequest do
  use User.Web, :model

  @primary_key {:id, :binary_id, autogenerate: true}


  schema "new_password_requests" do
    field :user_id, :string

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
      |> cast(params, [:user_id])
      |> validate_required([:user_id])
  end
end
