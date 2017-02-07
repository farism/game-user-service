defmodule User.NewPasswordRequest do
  use User.Web, :model

  schema "new_password_requests" do
    field :user_id, :string
    field :reset_code, :string

    timestamps()
  end

  def insert_changeset(struct, params \\ %{}) do
    struct
      |> cast(params, [:user_id, :reset_code])
      |> validate_required([:user_id, :reset_code])
  end
end
