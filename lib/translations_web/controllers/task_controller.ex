defmodule TranslationsWeb.TaskController do
  use TranslationsWeb, :controller

  alias Translations.Tasks

  def assign_task(conn, %{"project_id" => project_id, "translator_id" => translator_id}) do
    with %Tasks.Translator{} = translator <- Tasks.find_translator(translator_id),
         %Tasks.TranslationProject{} = project <- Tasks.find_translation_project(project_id),
         {:ok, %Tasks.Task{} = task} <- Tasks.assign_translator(project, translator) do
      conn
      |> put_status(201)
      |> json(task |> Map.take([:id, :target_language, :translator_id, :translation_project_id]))
    else
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(400) |> json(%{errors: changeset |> collect_errors})
    end
  end

  def assign_tasks(conn, %{"id" => project_id}) do
    with %Tasks.TranslationProject{} = translation_project <- Tasks.find_translation_project(project_id),
         {:ok, %Tasks.TranslationProject{tasks: tasks} = project_with_assigned_tasks} <-
           Tasks.assign_translators(translation_project) do
      conn |> put_status(201) |> json(tasks |> Enum.map(&Map.take(&1, [:id, :translator_id, :target_language])))
    else
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(400) |> json(%{errors: changeset |> collect_errors()})
    end
  end

  def get_project_info(conn, %{"id" => project_id}) do
    with %Tasks.TranslationProject{} = translation_project <- Tasks.find_translation_project(project_id),
         %{} = info <- Tasks.build_info(translation_project) do
      conn |> put_status(200) |> json(info)
    else
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
    end
  end

  defp collect_errors(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.reduce(%{}, fn {key, {message, _}}, acc ->
      acc |> Map.update(key, [message], fn errors -> errors ++ [message] end)
    end)
  end
end
