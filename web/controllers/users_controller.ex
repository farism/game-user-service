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

  defparams register_params %{
    email!: :string,
    password!: :string,
    username!: :string
  }

  def register(conn, params) do
    with true <- validate_params(register_params(params)),
         {:ok, user} <- insert_user(params)
    do
      conn |> json(user)
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams login_params %{
    email!: :string,
    password!: :string,
  }

  def login(conn, params) do
    with true <- validate_params(login_params(params)),
         {:ok, user} <- get_user(email: params["email"]),
         {:ok, user} <- validate_user_password(user, params["password"])
    do
      conn |> json(user)
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams forgot_password_params %{
    email!: :string
  }

  def forgot_password(conn, params) do
    with true <- validate_params(forgot_password_params(params)),
         {:ok, user} <- get_user(email: params["email"]),
         {:ok, new_password_request} <- insert_new_password_request(user),
         :ok <- send_reset_password_email(user, new_password_request)
    do
      conn |> json(%{message: "Reset password email sent"})
    else
      {:error, "Invalid request"} ->
        conn |> json(%{message: "Reset password email sent"})
      {:error, err} ->
        conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams new_password_params %{
    reset_code!: :string,
    password!: :string,
  }

  def new_password(conn, params) do
    with true <- validate_params(new_password_params(params)),
         {:ok, new_password_request} <- get_new_password_request(params["reset_code"]),
         true <- validate_new_password_request(new_password_request),
         {:ok, user} <- get_user(id: new_password_request.user_id),
         :ok <- send_reset_password_email(user, new_password_request)
    do
      conn |> json(%{message: "Password reset"})
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defparams change_password_params %{
    email!: :string,
    password!: :string,
    password_new!: :string,
  }

  def change_password(conn, params) do
    input = change_password_params(params)

    with true <- validate_params(change_password_params(params)),
         {:ok, user} <- get_user(email: params["email"]),
         {:ok, user} <- validate_user_password(user, params["password"]),
         {:ok, _} <- update_user_password(user, params["password_new"])
    do
      conn |> json(%{message: "Password changed"})
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defp get_user(params) do
    case Repo.get_by(User, params) do
      nil -> {:error, "Invalid request"}
      user -> {:ok, user}
    end
  end

  defp insert_user(params) do
    {salt, hash} = gen_salt_and_hash(params["password"])
    params = Map.merge(params, %{"password" => hash, "salt" => salt})

    User.changeset(%User{}, params)
      |> Repo.insert
      |> case do
          {:ok, user} -> {:ok, user}
          {:error, changeset} -> {:error, display_errors(changeset)}
         end
  end

  defp update_user_password(user, password) do
    {salt, hash} = gen_salt_and_hash(password)

    user
      |> Ecto.Changeset.change(salt: salt, password: hash)
      |> Repo.update
      |> case do
          {:ok, _} -> {:ok, "Password changed"}
          {:error, _} -> {:error, "Invalid request"}
         end
  end

  defp get_new_password_request(reset_code) do
    Repo.get(NewPasswordRequest, reset_code)
      |> case do
          nil -> {:error, "Invalid request"}
          new_password_request -> {:ok, new_password_request}
         end
  end

  defp insert_new_password_request(user) do
    NewPasswordRequest.changeset(%NewPasswordRequest{}, %{ user_id: user.id })
      |> Repo.insert
      |> case do
          {:ok, new_password_request} -> {:ok, new_password_request}
          {:error, changeset} -> {:error, display_errors(changeset)}
         end
  end

  defp send_reset_password_email(user, new_password_request) do
    send_email to: user.email,
      from: "noreply@mmo.com",
      subject: "Reset password",
      html: new_password_request.id

    :ok
  end

  defp validate_new_password_request(new_password_request) do
    if Timex.diff(Timex.now, new_password_request.inserted_at, :hours) < 24 do
      true
    else
      {:error, "Invalid request"}
    end
  end

  defp validate_user_password(user, password) do
    hash = Comeonin.Bcrypt.hashpass(password, user.salt)
    case user.password == hash do
      true -> {:ok, user}
      false -> {:error, "Invalid request"}
    end
  end

  defp gen_salt_and_hash(password) do
    salt = Comeonin.Bcrypt.gen_salt
    hash = Comeonin.Bcrypt.hashpass(password, salt)
    {salt, hash}
  end

  defp validate_params(changeset) do
    if changeset.valid? do
      true
    else
      {:error, display_errors(changeset)}
    end
  end

  defp display_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
