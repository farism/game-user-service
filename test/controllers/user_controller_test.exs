defmodule User.UserControllerTest do
  require Logger
  use User.ConnCase
  use ExUnit.Case

  @register_path "/api/register/"
  @activate_path "/api/activate/"
  @login_path "/api/login/"
  @forgot_password_path "/api/forgot-password/"
  @new_password_path "/api/new-password/"
  @change_password_path "/api/change-password/"

  defp read_email_file(path) do
    path
      |> Path.expand(__DIR__)
      |> File.read!
      |> Poison.Parser.parse(keys: :atoms)
      |> case do
          {:ok, body} -> body
          other -> %{}
         end
  end

  defp get_user_activation_from_email(email) do
    user = User.Repo.get_by!(User.User, email: email)
    User.Repo.get_by!(User.UserActivation, user_id: user.id)
  end

  describe "POST #{@register_path}" do

    test "returns 400 when `email`, `password`, or `username` params are missing" do
      response = build_conn()
        |> post(@register_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "email" => ["can't be blank"],
          "password" => ["can't be blank"],
          "username" => ["can't be blank"]
        }
      }
    end

    test "returns 400 when `email` or `username` are already taken" do
      response = build_conn()
        |> post(@register_path, [email: "jane@doe.com", password: "pw", username: "janedoe"])
        |> post(@register_path, [email: "jane@doe.com", password: "pw", username: "janedoe2"])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "email" => ["has already been taken"]
        }
      }

      response = build_conn()
        |> post(@register_path, [email: "john@smith.com", password: "pw", username: "johnsmith"])
        |> post(@register_path, [email: "john2@smith.com", password: "pw", username: "johnsmith"])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "username" => ["has already been taken"]
        }
      }
    end

    test "returns 200 when user is inserted successfully" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> json_response(200)
        |> Map.delete("inserted_at")

      assert response == %{
        "email" => "john@doe.com",
        "username" => "johndoe"
      }
    end

    test "sends an email" do
      build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> json_response(200)

      email = read_email_file("../../priv/mailgun.json")

      assert Map.take(email, [:to, :from, :subject]) == %{
        to: "john@doe.com",
        from: "noreply@mmo.com",
        subject: "Welcome"
      }
    end
  end

  describe "POST #{@activate_path}" do

    test "returns 400 when `activation_code` param is missing" do
      response = build_conn()
        |> post(@activate_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "activation_code" => ["can't be blank"]
        }
      }
    end

    test "returns 400 when activation code can't be found" do
      response = build_conn()
        |> post(@activate_path, [activation_code: Ecto.UUID.generate()])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 400 when activation code is used twice" do
      user_activation = build_conn()
        |> post(@register_path, [email: "john@smith.com", password: "pw", username: "johnsmith"])
        |> json_response(200)
        |> Map.get("email")
        |> get_user_activation_from_email()

      response = build_conn()
        |> post(@activate_path, [activation_code: user_activation.id])
        |> post(@activate_path, [activation_code: user_activation.id])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 200 when activation code is found" do
      response = build_conn()
        |> post(@activate_path, [activation_code: Ecto.UUID.generate()])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

  end

  describe "POST #{@login_path}" do

    test "returns 400 when `email` or `password` params are missing" do
      response = build_conn()
        |> post(@login_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "email" => ["can't be blank"],
          "password" => ["can't be blank"]
        }
      }
    end

    test "returns 400 when email does not exist" do
      response = build_conn()
        |> post(@login_path, [email: "john@doe.com", password: "pw"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 400 when email exists but incorrect password" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@login_path, [email: "john@doe.com", password: "wrong"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 400 when email exists but user is inactive" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@login_path, [email: "john@doe.com", password: "pw"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 200 when user is found successfully" do
      user_activation = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> json_response(200)
        |> Map.get("email")
        |> get_user_activation_from_email()

      conn = build_conn()
        |> post(@activate_path, [activation_code: user_activation.id])
        |> post(@login_path, [email: "john@doe.com", password: "pw"])

      assert get_resp_header(conn, "authorization") != ""
      assert get_resp_header(conn, "x-expires") != ""

      response = conn
        |> json_response(200)
        |> Map.delete("inserted_at")

      assert response == %{
        "email" => "john@doe.com",
        "username" => "johndoe"
      }
    end

  end

  describe "POST #{@forgot_password_path}" do

    test "returns 400 when `email` param is missing" do
      response = build_conn()
        |> post(@forgot_password_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "email" => ["can't be blank"]
        }
      }
    end

    test "returns 200 when `email` param exists" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@forgot_password_path, [email: "john@doe.com"])
        |> json_response(200)

      assert response == %{
        "message" => "Reset password email sent"
      }
    end

    test "returns 200 even when email doesn't exist in db" do
      response = build_conn()
        |> post(@forgot_password_path, [email: "fake_random@email.com"])
        |> json_response(200)

      assert response == %{
        "message" => "Reset password email sent"
      }
    end

    test "sends an email" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@forgot_password_path, [email: "john@doe.com"])
        |> json_response(200)

      email = read_email_file("../../priv/mailgun.json")

      assert Map.take(email, [:to, :from, :subject]) == %{
        to: "john@doe.com",
        from: "noreply@mmo.com",
        subject: "Reset password"
      }
    end
  end

  describe "POST #{@new_password_path}" do
    test "returns 400 when `reset_code` or `password` params are missing" do
      response = build_conn()
        |> post(@new_password_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "reset_code" => ["can't be blank"],
          "password" => ["can't be blank"]
        }
      }
    end

    test "returns 400 when `reset_code` is invalid or expired" do
      build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@forgot_password_path, [email: "john@doe.com"])

      email = read_email_file("../../priv/mailgun.json")

      # bad uuid
      response = build_conn()
        |> post(@new_password_path, [reset_code: Ecto.UUID.generate(), password: "newpw"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request",
      }

      # expired
      User.NewPasswordRequest
        |> User.Repo.get(email.html)
        |> case do
            nil -> nil
            request -> request
              |> Ecto.Changeset.change(inserted_at: Timex.shift(request.inserted_at, hours: -48))
           end
        |> Repo.update

      response = build_conn()
        |> post(@new_password_path, [reset_code: email.html, password: "newpw"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request",
      }
    end

    test "returns 200 when `reset_code` is valid" do
      build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@forgot_password_path, [email: "john@doe.com"])

      email = read_email_file("../../priv/mailgun.json")

      response = build_conn()
        |> post(@new_password_path, [reset_code: email.html, password: "newpw"])
        |> json_response(200)

      assert response == %{
        "message" => "Password reset",
      }
    end
  end

  describe "POST #{@change_password_path}" do
    test "returns 400 when `email`, `password` or `password_new` params are missing" do
      response = build_conn()
        |> post(@change_password_path, [])
        |> json_response(400)

      assert response == %{
        "error" => %{
          "email" => ["can't be blank"],
          "password" => ["can't be blank"],
          "password_new" => ["can't be blank"]
        }
      }
    end

    test "returns 400 when user could not be found" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@change_password_path, [email: "john2@doe.com", password: "pw", password_new: "pw2"])
        |> json_response(400)

      assert response == %{
        "error" => "Invalid request"
      }
    end

    test "returns 200 when password was changed" do
      response = build_conn()
        |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
        |> post(@change_password_path, [email: "john@doe.com", password: "pw", password_new: "pw2"])
        |> json_response(200)

      assert response == %{
        "message" => "Password changed"
      }
    end

  end

end
