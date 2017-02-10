defmodule User.GuardianToken do
  use User.Web, :controller

  def unauthenticated(conn, _params) do
    conn
      |> json("You must be signed in to access this page")
  end

  def unauthorized(conn, _params) do
    conn
      |> json("You must be signed in to access this page")
  end
end
