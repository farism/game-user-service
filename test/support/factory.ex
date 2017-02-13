defmodule User.Factory do
  use ExMachina.Ecto, repo: User.Repo

  def user_factory do
    salt = Comeonin.Bcrypt.gen_salt

    %User.User{
      email: "john@doe.com",
      password: Comeonin.Bcrypt.hashpass("pw", salt),
      salt: salt,
      username: "johndoe"
    }
  end

  def user_activation_factory do
    %User.UserActivation{}
  end

  def new_password_request_factory do
    %User.NewPasswordRequest{}
  end
end
