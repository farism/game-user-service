defmodule User.UsersController do
  require Logger
  use User.Web, :controller
  use Params
  use Mailgun.Client,
    mode: Mix.env,
    test_file_path: "priv/mailgun.json",
    domain: Application.get_env(:user, :mailgun_domain),
    key: Application.get_env(:user, :mailgun_key)
  alias User.Repo
  alias User.NewPasswordRequest
  alias User.UserActivation
  alias User.User

  # param validation changesets

  defparams register_params %{
    email!: :string,
    password!: :string,
    username!: :string
  }

  defparams activate_params %{
    activation_code!: :string
  }

  defparams login_params %{
    email!: :string,
    password!: :string,
  }

  defparams forgot_password_params %{
    email!: :string
  }

  defparams new_password_params %{
    reset_code!: :string,
    password!: :string,
  }

  defparams change_password_params %{
    email!: :string,
    password!: :string,
    password_new!: :string,
  }

  # actions

  def register(conn, params) do
    with true <- validate_params(register_params(params)),
         {:ok, user} <- insert_user(params),
         {:ok, user_activation} <- insert_user_activation(%{user_id: user.id}),
         :ok <- send_registration_email(user, user_activation)
    do
      conn |> json(user)
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  def activate(conn, params) do
    with true <- validate_params(activate_params(params)),
         {:ok, user_activation} <- get_user_activation(params["activation_code"]),
         {:ok, user} <- get_user(id: user_activation.user_id),
         {:ok, user} <- set_user_as_active(user),
         {:ok, user_activation} <- delete_user_activation(user_activation)
    do
      conn |> json(%{message: "User activated"})
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  def login(conn, params) do
    with true <- validate_params(login_params(params)),
         {:ok, user} <- get_user(email: params["email"]),
         true <- validate_user_password(user, params["password"]),
         true <- validate_user_active(user),
         conn <- set_auth_and_exp_headers(conn, user)
    do
      conn |> json(user)
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

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

  def change_password(conn, params) do
    input = change_password_params(params)

    with true <- validate_params(change_password_params(params)),
         {:ok, user} <- get_user(email: params["email"]),
         true <- validate_user_password(user, params["password"]),
         {:ok, user} <- update_user_password(user, params["password_new"])
    do
      conn |> json(%{message: "Password changed"})
    else
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  # private

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

  defp get_user(params) do
    case Repo.get_by(User, params) do
      nil -> {:error, "Invalid request"}
      user -> {:ok, user}
    end
  end

  defp update_user_password(user, password) do
    {salt, hash} = gen_salt_and_hash(password)

    user
      |> Ecto.Changeset.change(salt: salt, password: hash)
      |> Repo.update
      |> case do
          {:ok, user} -> {:ok, "Password changed"}
          {:error, _} -> {:error, "Invalid request"}
         end
  end

  defp set_user_as_active(user) do
    user
      |> Ecto.Changeset.change(active: true)
      |> Repo.update
      |> case do
          {:ok, user} -> {:ok, "User activated"}
          {:error, _} -> {:error, "Invalid request"}
         end
  end

  defp insert_user_activation(params) do
    UserActivation.changeset(%UserActivation{}, params)
      |> Repo.insert
      |> case do
          {:ok, user_activation} -> {:ok, user_activation}
          {:error, changeset} -> {:error, display_errors(changeset)}
         end
  end

  defp get_user_activation(reset_code) do
    Repo.get(UserActivation, reset_code)
      |> case do
          nil -> {:error, "Invalid request"}
          user_activation -> {:ok, user_activation}
         end
  end

  defp delete_user_activation(user_activation) do
    user_activation
      |> Repo.delete
      |> case do
          {:ok, user_activation} -> {:ok, user_activation}
          {:error, changeset} -> {:error, display_errors(changeset)}
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

  defp send_registration_email(user, user_activation) do
    send_email to: user.email,
      from: "noreply@mmo.com",
      subject: "Welcome",
      html: user_activation.id

    :ok
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
    if user.password == hash do
      true
    else
      {:error, "Invalid request"}
    end
  end

  defp validate_user_active(user) do
    if user.active do
      true
    else
      {:error, "Invalid request"}
    end
  end

  defp gen_salt_and_hash(password) do
    salt = Comeonin.Bcrypt.gen_salt
    hash = Comeonin.Bcrypt.hashpass(password, salt)
    {salt, hash}
  end

  defp set_auth_and_exp_headers(conn, user) do
    with conn <- Guardian.Plug.api_sign_in(conn, user),
         jwt <- Guardian.Plug.current_token(conn),
         {:ok, claims} <- Guardian.Plug.claims(conn),
         exp <- Map.get(claims, "exp")
    do
      conn
        |> put_resp_header("authorization", "Bearer #{jwt}")
        |> put_resp_header("x-expires", "#{exp}")
    else
      {:error, _} -> conn
    end
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
