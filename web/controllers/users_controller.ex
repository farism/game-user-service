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
  alias User.User

  defparams register_validation %{
    email!: :string,
    password!: :string,
    username!: :string
  }

  def register(conn, params) do
    changeset = register_validation(params)

    if changeset.valid? do
      salt = Comeonin.Bcrypt.gen_salt
      hash = Comeonin.Bcrypt.hashpass params["password"], salt

      params = Map.merge(params, %{
        "password" => hash,
        "salt" => salt
      })

      case %User{} |> User.insert_changeset(params) |> Repo.insert do
        {:ok, user} ->
          Logger.info "Inserted user - #{inspect user}"
          json conn, user
        {:error, changeset} ->
          Logger.info "Error inserting user - #{inspect changeset.errors}"
          conn |> put_status(400) |> json(errors(changeset))
      end
    else
      conn |> put_status(400) |> json(errors(changeset))
    end
  end

  defparams login_validation %{
    email!: :string,
    password!: :string,
  }

  def login(conn, params) do
    changeset = login_validation(params)

    if changeset.valid? do
      user = Repo.get_by(User, email: params["email"])

      if user do
        Logger.info "Found user - #{inspect user}"
        hash = Comeonin.Bcrypt.hashpass params["password"], user.salt

        if user.password == hash do
          json conn, user
        else
          Logger.info "Incorrect password for user - #{params["email"]}"
          conn |> put_status(400) |> json(%{error: "Invalid request"})
        end
      else
        Logger.info "Could not find user by email - #{params["email"]}"
        conn |> put_status(400) |> json(%{error: "Invalid request"})
      end
    else
      conn |> put_status(400) |> json(errors(changeset))
    end
  end

  defparams forgot_password_validation %{
    email!: :string
  }

  def forgot_password(conn, params) do
    changeset = forgot_password_validation(params)

    if changeset.valid? do
      user = Repo.get_by(User, email: params["email"])


      if user do
        Logger.info "Found user - #{inspect user}"
        send_email to: user.email,
          from: "noreplay@game.com",
          subject: "Reset password",
          html: "#{Ecto.UUID.generate()}"
      else
        Logger.warn "Could not find user by email - #{params["email"]}"
      end

      json conn, %{message: "Reset password email sent"}
    else
      conn |> put_status(400) |> json(errors(changeset))
    end
  end

  def new_password(conn, params) do

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
