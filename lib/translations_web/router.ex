defmodule TranslationsWeb.Router do
  use TranslationsWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", TranslationsWeb do
    pipe_through(:api)

    post("/project/:project_id/assign_task/:translator_id", TaskController, :assign_task)
    post("/project/assign_all", TaskController, :assign_all)
    post("/project/:id/assign_tasks", TaskController, :assign_tasks)
    get("/project/:id", TaskController, :get_project_info)
  end
end
