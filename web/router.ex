defmodule User.Router do
  use User.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  scope "/api", User do
    pipe_through :api
    post "/register", UsersController, :register
    post "/login", UsersController, :login
    post "/forgot-password", UsersController, :forgot_password
    post "/new-password", UsersController, :new_password
    post "/change-password", UsersController, :change_password
  end
end
