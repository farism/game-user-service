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
    params
      |> register_params
      |> params_valid
      |> case do
        true ->
          {salt, hash} = hashpass(params["password"])
          params = Map.merge(params, %{"password" => hash, "salt" => salt})

          %User{}
            |> User.changeset(params)
            |> Repo.insert
            |> case do
                {:error, changeset} -> {:error, errors(changeset)}
                other -> other
               end
        other -> other
      end
      |> case do
        {:ok, user} -> conn |> json(user)
        {:error, err} -> conn |> put_status(400) |> json(%{error: err})
      end
  end

  defparams login_params %{
    email!: :string,
    password!: :string,
  }

  def login(conn, params) do
    params
      |> login_params
      |> params_valid
      |> case do
        true ->
          Repo.get_by(User, email: params["email"])
            |> case do
                nil -> {:error, "Invalid login"}
                user ->
                  hash = Comeonin.Bcrypt.hashpass(params["password"], user.salt)
                  cond do
                    user.password == hash -> {:ok, user}
                    true -> {:error, "Invalid login"}
                  end
               end
        other -> other
      end
      |> case do
        {:ok, user} -> conn |> json(user)
        {:error, err} -> conn |> put_status(400) |> json(%{error: err})
      end
  end

  defparams forgot_password_params %{
    email!: :string
  }

  def forgot_password(conn, params) do
    params
      |> forgot_password_params
      |> params_valid
      |> case do
        true ->
          Repo.get_by(User, email: params["email"])
            |> case do
              nil -> :ok
              user ->
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
            end
        other -> other
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
              # reset_code was created less than 24 hours ago
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
              {salt, hash} = hashpass(params["password"])
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

  defparams change_password_input %{
    email!: :string,
    password!: :string,
    password_new!: :string,
  }

  def change_password(conn, params) do
    input = change_password_input(params)

    if input.valid? do
      #get request
      Repo.get_by(User, email: params["email"])
        |> case do
            nil -> {:error, "Invalid request"}
            user ->
              hash = Comeonin.Bcrypt.hashpass(params["password"], user.salt)
              cond do
                user.password == hash -> {:ok, user}
                true -> {:error, "Invalid request"}
              end
           end
        # update password
        |> case do
            {:ok, user} ->
              {salt, hash} = hashpass(params["password_new"])
              user
                |> Ecto.Changeset.change(salt: salt, password: hash)
                |> Repo.update
            other -> other
           end
        # send response
        |> case do
            {:ok, _} -> {:ok, "Password changed"}
            {:error, _} -> {:error, "Invalid request"}
           end
    else
      {:error, errors(input)}
    end
    |> case do
      {:ok, msg} -> conn |> json(%{message: msg})
      {:error, err} -> conn |> put_status(400) |> json(%{error: err})
    end
  end

  defp hashpass(password) do
    salt = Comeonin.Bcrypt.gen_salt
    hash = Comeonin.Bcrypt.hashpass(password, salt)
    {salt, hash}
  end

  defp params_valid(changeset) do
    if changeset.valid? do
      true
    else
      {:error, errors(changeset)}
    end
  end

  defp errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
