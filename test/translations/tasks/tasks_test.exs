defmodule Translations.Tasks.TasksTest do
  use Translations.DataCase

  alias Translations.Tasks

  describe "find_translator/1" do
    test "returns translator matched by id" do
      translator = insert(:translator)
      assert Tasks.find_translator(translator.id) == translator
    end

    test "returns nil if no translator matched" do
      assert Tasks.find_translator(-1) == nil
    end
  end

  describe "find_translation_project/1" do
    test "returns project matched by id" do
      translation_project = insert(:translation_project)
      assert Tasks.find_translation_project(translation_project.id) == translation_project
    end

    test "returns nil if no project matched" do
      assert Tasks.find_translation_project(-1) == nil
    end
  end

  describe "assign_translator/2" do
    test "creates task record, assigning translator to task" do
      translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 10.0)

      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["HR", "GE"],
          estimated_hours_per_language: 2.0,
          deadline_in_days: 10
        )

      assert {:ok, task} = Tasks.assign_translator(project, translator)
      assert task.translator_id == translator.id
      assert task.translation_project.id == project.id
      assert task.target_language == "HR"
    end

    test "fails if translator does not know project's original language" do
      translator = insert(:translator, known_languages: ["GE", "HR"], hours_per_day: 10.0)

      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["HR", "GE"],
          estimated_hours_per_language: 2.0,
          deadline_in_days: 10
        )

      assert {:error, changeset} = Tasks.assign_translator(project, translator)
      assert {error, _} = changeset.errors[:target_language]
      assert error =~ "not known"
    end

    test "fails if translator cannot complete translation in time" do
      translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 1.0)

      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["HR", "GE"],
          estimated_hours_per_language: 10.0,
          deadline_in_days: 1
        )

      assert {:error, changeset} = Tasks.assign_translator(project, translator)
      assert {error, _} = changeset.errors[:target_language]
      assert error =~ "cannot reach deadline"
    end

    test "fails if translator cannot complete translation in time due to other tasks assigned" do
      translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 8.0)

      previous_project =
        insert(:translation_project,
          original_language: "HR",
          target_languages: ["EN"],
          estimated_hours_per_language: 16.0,
          deadline_in_days: 2
        )

      insert(:task, translator: translator, translation_project: previous_project, target_language: "EN")

      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["HR", "GE"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      assert {:error, changeset} = Tasks.assign_translator(project, translator)
      assert {error, _} = changeset.errors[:target_language]
      assert error =~ "cannot reach deadline"
    end

    test "fails if project has all languages taken" do
      translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 8.0)

      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["HR", "GE"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      insert(:task, translation_project: project, target_language: "HR")
      insert(:task, translation_project: project, target_language: "GE")

      assert {:error, changeset} = Tasks.assign_translator(project, translator)
      assert {error, _} = changeset.errors[:target_language]
      assert error =~ "incompatible"
    end
  end
end
