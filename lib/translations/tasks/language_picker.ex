defmodule Translations.Tasks.LanguagePicker do
  alias Translations.Tasks.{Translator, TranslationProject, Task}
  alias Translations.{Repo, Utils}

  import Ecto.Query

  def get_available_languages(%Translator{known_languages: known} = translator, %TranslationProject{} = project) do
    with :original_language_known <- original_language_status(translator, project),
         :deadline_reachable <- deadline_status(translator, project),
         unassigned <- get_unassigned_languages(project),
         available when available != [] <- Utils.list_intersection(unassigned, known) do
      {:ok, available}
    else
      error when is_atom(error) -> {:error, error}
      [] -> {:error, :not_found}
    end
  end

  defp original_language_status(
         %Translator{known_languages: known_languages},
         %TranslationProject{original_language: original_language}
       ) do
    if original_language in known_languages, do: :original_language_known, else: :original_language_unknown
  end

  defp deadline_status(
         %Translator{id: id, hours_per_day: hours_per_day},
         %TranslationProject{
           estimated_hours_per_language: estimated_hours_per_language,
           deadline_in_days: deadline_in_days
         }
       ) do
    assigned_hours =
      TranslationProject
      |> join(:right, [p], t in Task, t.translation_project_id == p.id and t.translator_id == ^id)
      |> select([p, t], struct(p, [:estimated_hours_per_language]))
      |> Repo.aggregate(:sum, :estimated_hours_per_language)

    days_needed = ((assigned_hours || 0) + estimated_hours_per_language) / hours_per_day
    if days_needed > deadline_in_days, do: :deadline_unreachable, else: :deadline_reachable
  end

  defp get_unassigned_languages(%TranslationProject{id: id, target_languages: target_languages}) do
    taken_languages =
      Task
      |> where([t], t.translation_project_id == ^id)
      |> select([t], t.target_language)
      |> Repo.all()
      |> List.flatten()

    target_languages -- taken_languages
  end
end
