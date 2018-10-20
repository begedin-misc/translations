defmodule TranslationsWeb.TaskControllerTest do
  @moduledoc false

  use TranslationsWeb.ConnCase

  alias Translations.{Tasks, Repo}

  describe "POST /api/project/:project_id/assign_task/:translator_id" do
    test "assigns task if valid assignment", %{conn: conn} do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 8.0)

      path = task_path(conn, :assign_task, project, translator)

      assert response = conn |> post(path) |> json_response(201)

      assert Tasks.Task
             |> Repo.get_by(translator_id: translator.id, translation_project_id: project.id, target_language: "GE")
    end

    test "renders 400 with json error if invalid assignment", %{conn: conn} do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      translator = insert(:translator, known_languages: ["HR"], hours_per_day: 8.0)

      path = task_path(conn, :assign_task, project, translator)

      assert json = conn |> post(path) |> json_response(400)
      assert json["errors"]
    end

    test "renders 404 if project not found", %{conn: conn} do
      translator = insert(:translator)
      path = task_path(conn, :assign_task, -1, translator)
      assert json = conn |> post(path) |> json_response(404)
      assert json["error"]
    end

    test "renders 404 if translator not found", %{conn: conn} do
      project = insert(:translation_project)
      path = task_path(conn, :assign_task, project, -1)
      assert json = conn |> post(path) |> json_response(404)
      assert json["error"]
    end
  end

  describe "POST /api/project/:id/assign_tasks" do
    test "assigns translators to all languages of project", %{conn: conn} do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      _slow_ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 2.0)
      fast_ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 8.0)
      it_translator = insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 8.0)
      _slow_fr_translator = insert(:translator, known_languages: ["EN", "FR", "GE"], hours_per_day: 8.0)
      fast_fr_translator = insert(:translator, known_languages: ["EN", "FR", "GE"], hours_per_day: 10.0)
      hr_translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 10.0)

      path = task_path(conn, :assign_tasks, project)
      assert json = conn |> post(path) |> json_response(201)

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: fast_ge_translator.id,
               target_language: "GE"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: it_translator.id,
               target_language: "IT"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: fast_fr_translator.id,
               target_language: "FR"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: hr_translator.id,
               target_language: "HR"
             )
    end

    test "if project cannot be completed in time, makes no assignments", %{conn: conn} do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 2.0)
      insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 8.0)

      path = task_path(conn, :assign_tasks, project)
      assert json = conn |> post(path) |> json_response(400)
      assert json["errors"]["tasks"]
      refute Tasks.Task |> Repo.one()
    end

    test "renders 404 if project not found", %{conn: conn} do
      path = task_path(conn, :assign_tasks, -1)
      assert json = conn |> post(path) |> json_response(404)
      assert json["error"]
    end
  end

  describe "GET /api/project/:id" do
    test "renders project info", %{conn: conn} do
      project =
        insert(:translation_project,
          estimated_hours_per_language: 9.0,
          deadline_in_days: 2,
          original_language: "HR",
          target_languages: ["EN", "GE"]
        )

      translator_1 = insert(:translator, known_languages: ["HR", "GE"], hours_per_day: 9.0)
      insert(:task, translator: translator_1, translation_project: project, target_language: "GE")
      translator_2 = insert(:translator, known_languages: ["HR", "EN"], hours_per_day: 6.0)
      insert(:task, translator: translator_2, translation_project: project, target_language: "EN")

      path = task_path(conn, :get_project_info, project)
      assert json = conn |> get(path) |> json_response(200)

      assert json["id"] == project.id
      assert json["estimated_hours_per_language"] == 9.0
      assert json["deadline_in_days"] == 2
      assert json["original_language"] == "HR"
      assert json["target_languages"] == ["EN", "GE"]

      assert json["translators"]["GE"] ==
               %{
                 "id" => translator_1.id,
                 "name" => translator_1.name,
                 "known_languages" => ["HR", "GE"],
                 "hours_per_day" => 9.0
               }

      assert json["translators"]["EN"] ==
               %{
                 "id" => translator_2.id,
                 "name" => translator_2.name,
                 "known_languages" => ["HR", "EN"],
                 "hours_per_day" => 6.0
               }
    end

    test "renders 404 if project not found", %{conn: conn} do
      path = task_path(conn, :get_project_info, -1)
      assert json = conn |> get(path) |> json_response(404)
      assert json["error"]
    end
  end
end
