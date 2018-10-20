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

  describe "assign_translators/1" do
    test "assigns a translator for each project target language" do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 8.0)
      it_translator = insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 8.0)
      fr_translator = insert(:translator, known_languages: ["EN", "FR", "GE"], hours_per_day: 10.0)
      hr_translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 10.0)

      assert {:ok, _updated_project} = Tasks.assign_translators(project)

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: ge_translator.id, target_language: "GE")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: it_translator.id, target_language: "IT")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: fr_translator.id, target_language: "FR")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: hr_translator.id, target_language: "HR")
    end

    test "opts for the combination with the quickest completion time" do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      _slow_ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 8.0)
      ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 10.0)
      it_translator = insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 10.0)
      _slow_fr_translator = insert(:translator, known_languages: ["EN", "FR"], hours_per_day: 8.0)
      fr_translator = insert(:translator, known_languages: ["EN", "FR"], hours_per_day: 10.0)
      hr_translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 10.0)

      assert {:ok, _updated_project} = Tasks.assign_translators(project)

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: ge_translator.id, target_language: "GE")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: it_translator.id, target_language: "IT")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: fr_translator.id, target_language: "FR")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project.id, translator_id: hr_translator.id, target_language: "HR")
    end

    test "performs no assignments if not all languages can be covered" do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      _ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 8.0)
      _it_translator = insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 8.0)
      _fr_translator = insert(:translator, known_languages: ["EN", "FR", "GE"], hours_per_day: 10.0)

      assert {:error, changeset} = Tasks.assign_translators(project)
      assert {message, _} = changeset.errors[:tasks]
      assert message =~ "Not enough compatible translators"
      refute Repo.one(Tasks.Task)
    end

    test "performs no assignments if any covered language cannot be completed in time" do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      _too_slow_ge_translator = insert(:translator, known_languages: ["EN", "GE"], hours_per_day: 1.0)
      _it_translator = insert(:translator, known_languages: ["EN", "IT"], hours_per_day: 8.0)
      _fr_translator = insert(:translator, known_languages: ["EN", "FR"], hours_per_day: 8.0)
      _hr_translator = insert(:translator, known_languages: ["EN", "HR"], hours_per_day: 8.0)

      assert {:error, changeset} = Tasks.assign_translators(project)
      assert {message, _} = changeset.errors[:tasks]
      assert message =~ "Not enough compatible translators"
      refute Repo.one(Tasks.Task)
    end

    test "performs assignments if translator can complete multiple languages in time" do
      project =
        insert(:translation_project,
          original_language: "EN",
          target_languages: ["GE", "IT", "FR", "HR"],
          estimated_hours_per_language: 2.0,
          deadline_in_days: 2
        )

      speedy_translator = insert(:translator, known_languages: ["EN", "GE", "IT", "FR", "HR"], hours_per_day: 8.0)

      assert {:ok, _updated_project} = Tasks.assign_translators(project)

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: speedy_translator.id,
               target_language: "GE"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: speedy_translator.id,
               target_language: "IT"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: speedy_translator.id,
               target_language: "FR"
             )

      assert Tasks.Task
             |> Repo.get_by(
               translation_project_id: project.id,
               translator_id: speedy_translator.id,
               target_language: "HR"
             )
    end
  end

  describe "assign_all/0" do
    test "assigns translators to each project" do
      project_1 =
        insert(:translation_project,
          estimated_hours_per_language: 4.0,
          deadline_in_days: 2,
          original_language: "HR",
          target_languages: ["EN", "GE"]
        )

      project_2 =
        insert(:translation_project,
          estimated_hours_per_language: 6.0,
          deadline_in_days: 2,
          original_language: "IT",
          target_languages: ["FR", "RU"]
        )

      translator_1 = insert(:translator, hours_per_day: 12, known_languages: ["HR", "EN", "GE"])
      translator_2 = insert(:translator, hours_per_day: 12, known_languages: ["IT", "FR", "RU"])

      assert {2, 0} = Tasks.assign_all()

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_1.id, translator_id: translator_1.id, target_language: "EN")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_1.id, translator_id: translator_1.id, target_language: "GE")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_2.id, translator_id: translator_2.id, target_language: "FR")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_2.id, translator_id: translator_2.id, target_language: "RU")
    end

    test "returns failure counts if some assignments failed" do
      project_1 =
        insert(:translation_project,
          estimated_hours_per_language: 4.0,
          deadline_in_days: 2,
          original_language: "HR",
          target_languages: ["EN", "GE"]
        )

      project_2 =
        insert(:translation_project,
          estimated_hours_per_language: 50.0,
          deadline_in_days: 1,
          original_language: "IT",
          target_languages: ["FR", "RU"]
        )

      translator_1 = insert(:translator, hours_per_day: 12, known_languages: ["HR", "EN", "GE"])
      translator_2 = insert(:translator, hours_per_day: 12, known_languages: ["IT", "FR", "RU"])

      assert {1, 1} = Tasks.assign_all()

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_1.id, translator_id: translator_1.id, target_language: "EN")

      assert Tasks.Task
             |> Repo.get_by(translation_project_id: project_1.id, translator_id: translator_1.id, target_language: "GE")

      refute Tasks.Task
             |> Repo.get_by(translation_project_id: project_2.id, translator_id: translator_2.id, target_language: "FR")

      refute Tasks.Task
             |> Repo.get_by(translation_project_id: project_2.id, translator_id: translator_2.id, target_language: "RU")
    end
  end

  describe "get_project_info/1" do
    test "shows correct basic project info" do
      project =
        insert(:translation_project,
          original_language: "HR",
          target_languages: ["EN", "GE"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      assert project |> Tasks.get_info() == %{
               id: project.id,
               translators: %{},
               original_language: "HR",
               target_languages: ["EN", "GE"],
               estimated_hours_per_language: 8.0,
               deadline_in_days: 2,
               will_complete_in_days: nil
             }
    end

    test "shows assigned translators and completion time correctly" do
      project =
        insert(:translation_project,
          original_language: "HR",
          target_languages: ["EN", "GE"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      translator_1 = insert(:translator, known_languages: ["HR", "EN"], hours_per_day: 7.0, name: "Joe")
      insert(:task, translation_project: project, translator: translator_1, target_language: "EN")
      translator_2 = insert(:translator, known_languages: ["HR", "GE"], hours_per_day: 4.0, name: "James")
      insert(:task, translation_project: project, translator: translator_2, target_language: "GE")

      info = project |> Tasks.get_info()

      assert info[:translators] == %{
               "EN" => %{
                 hours_per_day: 7.0,
                 id: translator_1.id,
                 known_languages: ["HR", "EN"],
                 name: "Joe"
               },
               "GE" => %{
                 hours_per_day: 4.0,
                 id: translator_2.id,
                 known_languages: ["HR", "GE"],
                 name: "James"
               }
             }

      assert info[:will_complete_in_days] == 2.0
    end

    test "shows assigned translators and completion time correctly when one translator is assigned to multiple languages" do
      project =
        insert(:translation_project,
          original_language: "HR",
          target_languages: ["EN", "GE"],
          estimated_hours_per_language: 8.0,
          deadline_in_days: 2
        )

      translator_1 = insert(:translator, known_languages: ["HR", "EN", "GE"], hours_per_day: 8.0, name: "Joe")
      insert(:task, translation_project: project, translator: translator_1, target_language: "EN")
      insert(:task, translation_project: project, translator: translator_1, target_language: "GE")

      info = project |> Tasks.get_info()

      assert info[:translators] == %{
               "EN" => %{
                 hours_per_day: 8.0,
                 id: translator_1.id,
                 known_languages: ["HR", "EN", "GE"],
                 name: "Joe"
               },
               "GE" => %{
                 hours_per_day: 8.0,
                 id: translator_1.id,
                 known_languages: ["HR", "EN", "GE"],
                 name: "Joe"
               }
             }

      assert info[:will_complete_in_days] == 2.0
    end
  end
end
