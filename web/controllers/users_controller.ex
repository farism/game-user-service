defmodule User.UsersController do
  require Logger
  use User.Web, :controller
  use Params
  use Mailgun.Client,
    mode: :test,
    test_file_path: "priv/mailgun.json",
    domain: Application.get_env(:user, :mailgun_domain),
    key: Application.get_env(:user, :mailgun_key)
  alias User.Repo
  alias User.NewPasswordRequest
  alias User.User

  defparams register_input %{
    email!: :string,
    password!: :string,
    username!: :string
  }

  def register(conn, params) do
    input = register_input(params)

    if input.valid? do
      {salt, hash} = salt_hash(params["password"])
      params = Map.merge(params, %{"password" => hash, "salt" => salt})

      %User{}
        |> User.changeset(params)
        |> Repo.insert
        |> case do
            {:ok, user} -> {:ok, user}
            {:error, changeset} -> {:error, errors(changeset)}
           end
    else
      {:error, errors(input)}
    end
    |> case do
      {:ok, user} -> conn |> json(user)
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams login_input %{
    email!: :string,
    password!: :string,
  }

  def login(conn, params) do
    input = login_input(params)

    if input.valid? do
      User
        |> Repo.get_by(email: params["email"])
        |> case do
            nil -> {:error, "Invalid login"}
            user ->
              hash = Comeonin.Bcrypt.hashpass(params["password"], user.salt)
              cond do
                user.password == hash -> {:ok, user}
                true -> {:error, "Invalid login"}
              end
           end
    else
      {:error, errors(input)}
    end
    |> case do
      {:ok, user} -> conn |> json(user)
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams forgot_password_input %{
    email!: :string
  }

  def forgot_password(conn, params) do
    input = forgot_password_input(params)

    if input.valid? do
      user = Repo.get_by(User, email: params["email"])

      if user do
        %NewPasswordRequest{}
          |> NewPasswordRequest.changeset(%{ user_id: user.id })
          |> Repo.insert
          |> case do
              {:ok, request} ->
                send_email to: user.email,
                  from: "noreply@mmo.com",
                  subject: "Reset password",
                  html: request.id
                :ok
              {:error, changeset} ->
                {:error, errors(changeset)}
             end
      else
        :ok
      end
    else
      {:error, errors(input)}
    end
    |> case do
      :ok -> conn |> json(%{message: "Reset password email sent"})
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams new_password_input %{
    reset_code!: :string,
    password!: :string,
  }

  def new_password(conn, params) do
    input = new_password_input(params)

    if input.valid? do
      #get request
      Repo.get(NewPasswordRequest, params["reset_code"])
        |> case do
            nil -> {:error, "Reset code not found"}
            request -> {:ok, request}
           end
        # get user
        |> case do
            {:ok, request} ->
              if Timex.diff(Timex.now, request.inserted_at, :hours) < 24 do
                Repo.get(User, request.user_id)
                  |> case do
                      nil -> {:error, "User not found"}
                      user -> {:ok, user}
                     end
              else
                {:error, "Reset code expired"}
              end
            other -> other
           end
        # update password
        |> case do
            {:ok, user} ->
              {salt, hash} = salt_hash(params["password"])
              user
                |> Ecto.Changeset.change(salt: salt, password: hash)
                |> Repo.update
            other -> other
           end
        # send response
        |> case do
            {:ok, _} -> {:ok, "Password reset"}
            {:error, _} -> {:error, "Reset code is invalid or expired"}
           end
    else
      {:error, errors(input)}
    end
    |> case do
      {:ok, msg} -> conn |> json(%{message: msg})
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  def change_password(conn, params) do

  end

  defp salt_hash(password) do
    salt = Comeonin.Bcrypt.gen_salt
    hash = Comeonin.Bcrypt.hashpass(password, salt)
    {salt, hash}
  end

  defp errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
