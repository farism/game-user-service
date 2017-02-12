defmodule User.Router do
  use User.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    # plug Guardian.Plug.VerifyHeader
    # plug Guardian.Plug.EnsureAuthenticated, handler: Users.Token
    # plug Guardian.Plug.LoadResource
  end

  # Other scopes may use custom stacks.
  scope "/api", User do
    pipe_through :api
    post "/register", UsersController, :register
    post "/activate", UsersController, :activate
    post "/login", UsersController, :login
    post "/forgot-password", UsersController, :forgot_password
    post "/new-password", UsersController, :new_password
    post "/change-password", UsersController, :change_password
  end
end
