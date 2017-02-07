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
      salt = Comeonin.Bcrypt.gen_salt
      hash = Comeonin.Bcrypt.hashpass(params["password"], salt)

      params = Map.merge(params, %{
        "password" => hash,
        "salt" => salt
      })

      %User{}
        |> User.insert_changeset(params)
        |> Repo.insert
        |> case do
            {:ok, user} ->
              Logger.info "Inserted user - #{inspect user}"
              json conn, user
            {:error, changeset} ->
              Logger.info "Error inserting user - #{inspect changeset.errors}"
              conn |> put_status(400) |> json(errors(changeset))
           end

    else
      conn |> put_status(400) |> json(errors(input))
    end
  end

  defparams login_input %{
    email!: :string,
    password!: :string,
  }

  def login(conn, params) do
    input = login_input(params)

    if input.valid? do
      user = Repo.get_by(User, email: params["email"])

      if user do
        Logger.info "Found user - #{inspect user}"
        hash = Comeonin.Bcrypt.hashpass(params["password"], user.salt)

        if user.password == hash do
          conn |> json(user)
        else
          Logger.info "Incorrect password for user - #{params["email"]}"
          conn |> put_status(400) |> json(%{error: "Invalid request"})
        end
      else
        Logger.info "Could not find user by email - #{params["email"]}"
        conn |> put_status(400) |> json(%{error: "Invalid request"})
      end
    else
      conn |> put_status(400) |> json(errors(input))
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
        Logger.info "Found user - #{inspect user}"

        %NewPasswordRequest{}
          |> NewPasswordRequest.insert_changeset(%{ user_id: user.id })
          |> Repo.insert
          |> case do
              {:ok, request} ->
                Logger.info "Inserted password reset request - #{inspect request}"
                send_email to: user.email,
                  from: "noreplay@game.com",
                  subject: "Reset password",
                  html: request.id
              {:error, changeset} ->
                Logger.info "Error inserting user - #{inspect changeset.errors}"
                conn |> put_status(400) |> json(errors(changeset))
             end
      else
        Logger.warn "Could not find user by email - #{params["email"]}"
      end

      json conn, %{message: "Reset password email sent"}
    else
      conn |> put_status(400) |> json(errors(input))
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
            nil -> IO.inspect {:error, "Reset code not found"}
            request -> {:ok, request}
           end
        # get user
        |> case do
            {:ok, request} ->
              age = Timex.diff(Timex.now, request.inserted_at, :hours)
              cond do
                age < 24 ->
                  Repo.get(User, request.user_id)
                    |> case do
                        nil -> {:error, "User not found"}
                        user -> {:ok, user}
                       end
                true -> {:error, "Reset code expired"}
              end
            other -> other
           end
        # update password
        |> case do
            {:ok, user} ->
              hash = Comeonin.Bcrypt.hashpass(params["password"], user.salt)
              user
                |> Ecto.Changeset.change(password: hash)
                |> Repo.update
            other -> other
           end
        # send response
        |> case do
            {:ok, _} ->
              conn |> json %{message: "Password reset"}
            {:error, _} ->
              conn |> put_status(400) |> json %{error: "Reset code is invalid or expired"}
           end


      # if inserted_at < 24 do
      #
      #   conn |> json %{}
      # else
      #   conn |> put_status(400) |> json %{error: "Reset code is invalid or expired"}
      # end
    else
      conn |> put_status(400) |> json(errors(input))
    end
  end

  def change_password(conn, params) do

  end

  defp errors(validator) do
    Ecto.Changeset.traverse_errors(validator, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
