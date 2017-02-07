defmodule User.UserControllerTest do
  require Logger
  use User.ConnCase
  use ExUnit.Case

  @register_path "/api/register/"
  @login_path "/api/login/"
  @forgot_password_path "/api/forgot-password/"
  @new_password_path "/api/new-password/"
  @change_password_path "/api/change-password/"

  defp read_email_file(path) do
    path
      |> Path.expand(__DIR__)
      |> File.read
      |> case do
          {:ok, body} -> Poison.Parser.parse(body, keys: :atoms)
          other -> other
         end
      |> case do
          {:ok, body} -> body
          other -> %{}
         end
  end

  test "#register returns 400 when `email`, `password`, or `username` params are missing" do
    response = build_conn()
      |> post(@register_path, [])
      |> json_response(400)

    assert response == %{
      "email" => ["can't be blank"],
      "password" => ["can't be blank"],
      "username" => ["can't be blank"]
    }
  end

  test "#register returns 400 when `email` or `username` are already taken" do
    response = build_conn()
      |> post(@register_path, [email: "jane@doe.com", password: "pw", username: "janedoe"])
      |> post(@register_path, [email: "jane@doe.com", password: "pw", username: "janedoe2"])
      |> json_response(400)

    assert response == %{
      "email" => ["has already been taken"]
    }

    response = build_conn()
      |> post(@register_path, [email: "john@smith.com", password: "pw", username: "johnsmith"])
      |> post(@register_path, [email: "john2@smith.com", password: "pw", username: "johnsmith"])
      |> json_response(400)

    assert response == %{
      "username" => ["has already been taken"]
    }
  end

  test "#register returns 200 when user is inserted successfully" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> json_response(200)
      |> Map.delete("inserted_at")

    assert response == %{
      "email" => "john@doe.com",
      "username" => "johndoe"
    }
  end

  test "#login returns 400 when `email` or `password` params are missing" do
    response = build_conn()
      |> post(@login_path, [])
      |> json_response(400)

    assert response == %{
      "email" => ["can't be blank"],
      "password" => ["can't be blank"]
    }
  end

  test "#login returns 400 when email does not exist" do
    response = build_conn()
      |> post(@login_path, [email: "john@doe.com", password: "pw"])
      |> json_response(400)

    assert response == %{
      "error" => "Invalid request"
    }
  end

  test "#login returns 400 when email exists but incorrect password" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@login_path, [email: "john@doe.com", password: "wrong"])
      |> json_response(400)

    assert response == %{
      "error" => "Invalid request"
    }
  end

  test "#login returns 200 when user is fetched successfully" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@login_path, [email: "john@doe.com", password: "pw"])
      |> json_response(200)
      |> Map.delete("inserted_at")

    assert response == %{
      "email" => "john@doe.com",
      "username" => "johndoe"
    }
  end

  test "#forgot_password returns 400 when `email` param is missing" do
    response = build_conn()
      |> post(@forgot_password_path, [])
      |> json_response(400)

    assert response == %{
      "email" => ["can't be blank"]
    }
  end

  test "#forgot_password returns 200 when `email` param exists" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@forgot_password_path, [email: "john@doe.com"])
      |> json_response(200)

    assert response == %{
      "message" => "Reset password email sent"
    }
  end

  test "#forgot_password returns 200 even when email doesn't exist in db" do
    response = build_conn()
      |> post(@forgot_password_path, [email: "fake_random@email.com"])
      |> json_response(200)

    assert response == %{
      "message" => "Reset password email sent"
    }
  end

  test "#forgot_password sends an email" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@forgot_password_path, [email: "john@doe.com"])
      |> json_response(200)

    email = read_email_file("../../priv/mailgun.json")

    assert Map.take(email, [:to, :from, :subject]) == %{
      to: "john@doe.com",
      from: "noreplay@game.com",
      subject: "Reset password"
    }
  end

  test "#new_password returns 400 when `reset_code` or `password` params are missing" do
    response = build_conn()
      |> post(@new_password_path, [])
      |> json_response(400)

    assert response == %{
      "reset_code" => ["can't be blank"],
      "password" => ["can't be blank"]
    }
  end

  test "#new_password returns 400 when `reset_code` is invalid or expired" do
    build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@forgot_password_path, [email: "john@doe.com"])

    email = read_email_file("../../priv/mailgun.json")

    response = build_conn()
      |> post(@new_password_path, [reset_code: email.html, password: "newpw"])
      |> json_response(400)

    assert response == %{
      "error" => ["Reset code is invalid or expired"],
    }
  end

end
