defmodule User.UserControllerTest do
  require Logger
  use User.ConnCase

  @register_path "/api/register/"
  @login_path "/api/login/"
  @forgot_password_path "/api/forgot-password/"
  @reset_password_path "/api/reset-password/"
  @change_password_path "/api/change-password/"

  test "#register returns 400 when `email` param is missing" do
    response = build_conn()
      |> post(@register_path, [password: "pw", username: "johndoe"])
      |> json_response(400)

    assert response == %{
      "email" => ["can't be blank"]
    }
  end

  test "#register returns 400 when `password` param is missing" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", username: "johndoe"])
      |> json_response(400)

    assert response == %{
      "password" => ["can't be blank"]
    }
  end

  test "#register returns 400 when `username` param is missing" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw"])
      |> json_response(400)

    assert response == %{
      "username" => ["can't be blank"]
    }
  end

  test "#register returns 400 when email has already been taken" do
    response = build_conn()
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> post(@register_path, [email: "john@doe.com", password: "pw", username: "johndoe"])
      |> json_response(400)

    assert response == %{
      "email" => ["has already been taken"],
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

  test "#login returns 400 when `email` param is missing" do
    response = build_conn()
      |> post(@login_path, [password: "pw"])
      |> json_response(400)

    assert response == %{
      "email" => ["can't be blank"]
    }
  end

  test "#login returns 400 when `password` param is missing" do
    response = build_conn()
      |> post(@login_path, [email: "john@doe.com"])
      |> json_response(400)

    assert response == %{
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

    email = "../../priv/mailgun.json"
      |> Path.expand(__DIR__)
      |> File.read
      |> case do
           {:ok, body} -> Poison.Parser.parse(body, keys: :atoms)
           _ ->
         end
      |> case do
           {:ok, json} -> json
           _ ->
         end

    assert Map.take(email, [:to, :from, :subject]) == %{
      to: "john@doe.com",
      from: "noreplay@game.com",
      subject: "Reset password"
    }
  end
end
