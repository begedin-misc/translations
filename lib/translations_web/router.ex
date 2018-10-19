defmodule TranslationsWeb.Router do
  use TranslationsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TranslationsWeb do
    pipe_through :api
  end
end
