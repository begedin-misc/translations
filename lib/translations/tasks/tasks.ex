defmodule Translations.Tasks do
  alias Translations.{Tasks.Translator, Tasks.TranslationProject, Tasks.LanguagePicker, Tasks.Task, Repo, Utils}
  alias Ecto.Changeset

  import Ecto.Query

  @doc """
  Retrieves a `Translations.Translator` record by id, returning `nil` if not found.
  """
  @spec find_translator(integer) :: nil | Translator.t()
  def find_translator(id), do: Translator |> Repo.get(id)

  @doc """
  Retrieves a `Translations.TranslationProject` record by id, returning `nil` if not found.
  """
  @spec find_translation_project(integer) :: nil | Translator.t()
  def find_translation_project(id), do: TranslationProject |> Repo.get(id)

  @doc """
  Assigns compatible translator to an available language on a translation project

  A language is available if there is no translator already assigned to it.

  A translator is compatible if
    - they know the language
    - their daily available hours, combined with already assigned translation tasks result in them being able to
    complete the new assignment within the project's deadline
  """
  @spec assign_translator(TranslationProject.t(), Translator.t()) :: {:ok, Task.t()} | {:error, Changeset.t()}
  def assign_translator(%TranslationProject{} = translation_project, %Translator{} = translator) do
    %Task{}
    |> Changeset.cast(%{}, [])
    |> Changeset.put_assoc(:translator, translator)
    |> Changeset.put_assoc(:translation_project, translation_project)
    |> pick_language(translator, translation_project)
    |> Changeset.validate_required(:target_language)
    |> Repo.insert()
  end

  defp pick_language(
         %Changeset{} = changeset,
         %Translator{} = translator,
         %TranslationProject{} = project
       ) do
    case LanguagePicker.get_available_languages(translator, project) do
      {:ok, languages} when languages != [] ->
        changeset |> Changeset.put_change(:target_language, languages |> List.first())

      {:error, :original_language_unknown} ->
        changeset |> Changeset.add_error(:target_language, "Original language not known by translator.")

      {:error, :deadline_unreachable} ->
        changeset |> Changeset.add_error(:target_language, "Translator cannot reach deadline.")

      {:error, :not_found} ->
        changeset
        |> Changeset.add_error(:target_language, "Available languages incompatible with translators known languages.")
    end
  end

  @doc """
  Assigns translators to all available languages on a translation project, under the condition that there are enough
  compatible translators to complete the project within the deadline.

  If the project is not completable, no translators are assigned.

  NOTE: The algorithm used is a greedy full search algorithm meaning it will fond the solution, if one is available, albeit
  at the cost of computation time and memory.
  """
  @spec assign_translators(TranslationProject.t()) :: {:ok, TranslationProject.t()} | {:error, Changeset.t()}
  def assign_translators(%TranslationProject{} = project) do
    project = project |> Repo.preload(:tasks)

    message = "Not enough compatible translators to complete project in time"

    project
    |> Changeset.cast(%{tasks: project |> get_task_params()}, [])
    |> Changeset.cast_assoc(:tasks, required: true, invalid_message: message, required_message: message)
    |> Repo.update()
  end

  @doc """
  For each project in the system, performs assignment of tasks using `assign_translators/1`.

  Projects are first sorted by amount of time needed to complete them, ascending, as an attempt to complete as many as possible.

  As soon as a single assignment fails, the function stops, keeping assinged projects and skipping those not assignable.
  """
  @spec assign_all() :: {integer, integer}
  def assign_all() do
    projects =
      TranslationProject
      |> Repo.all()
      |> Repo.preload(:tasks)
      |> Enum.sort_by(&TranslationProject.get_hours_needed/1)

    projects |> iteratively_assign_tasks()
  end

  @doc """
  Builds a map containing info about the projects, including basic information as well as assigned translators, mapped by language.
  """
  @spec get_info(TranslationProject.t()) :: map
  def get_info(%TranslationProject{} = project) do
    project = project |> Repo.preload(tasks: :translator)

    translator_data =
      project.tasks
      |> Enum.map(fn %{target_language: target_language, translator: translator} ->
        {target_language, translator |> Map.take([:id, :name, :hours_per_day, :known_languages])}
      end)
      |> Enum.into(%{})

    will_complete_in_days =
      project.tasks
      |> Enum.map(&Map.get(&1, :translator))
      |> Enum.group_by(&Map.get(&1, :id))
      |> Enum.map(fn {_id, instances} ->
        occurrences = Enum.count(instances)
        hours_per_day = instances |> List.first() |> Map.get(:hours_per_day)
        project.estimated_hours_per_language / hours_per_day * occurrences
      end)
      |> (fn
            [] -> nil
            times when is_list(times) -> Enum.max(times)
          end).()

    project
    |> Map.take([:id, :original_language, :target_languages, :estimated_hours_per_language, :deadline_in_days])
    |> Map.merge(%{translators: translator_data, will_complete_in_days: will_complete_in_days})
  end

  @spec iteratively_assign_tasks(list(TranslationProject.t())) :: {integer, integer}
  defp iteratively_assign_tasks(projects) do
    [project | rest] = projects
    first_result = project |> assign_translators()
    do_iteratively_assign_tasks(rest, first_result)
  end

  defp do_iteratively_assign_tasks(unassigned_projects, last_result, assigned_count \\ 0)

  defp do_iteratively_assign_tasks([project | rest], {:ok, _prev_assigned_project}, assigned_count) do
    do_iteratively_assign_tasks(rest, project |> assign_translators(), assigned_count + 1)
  end

  defp do_iteratively_assign_tasks(not_yet_assigned, {:error, _error}, assigned_count),
    do: {assigned_count, Enum.count(not_yet_assigned) + 1}

  defp do_iteratively_assign_tasks([], {:ok, _}, assigned_count), do: {assigned_count + 1, 0}

  def get_compatible_translators_grouped_by_target_languages(%TranslationProject{} = project) do
    translators_data = get_compatible_translator_data(project)

    project.target_languages
    |> Enum.map(fn language ->
      translators_who_know_language =
        translators_data |> Enum.filter(fn %{known_languages: known} -> language in known end)

      {language, translators_who_know_language}
    end)
  end

  defp get_task_params(%TranslationProject{} = project) do
    with language_data <- project |> get_compatible_translators_grouped_by_target_languages(),
         false <- language_data |> Enum.any?(&lacks_translators?/1),
         assignments when assignments != [] <-
           language_data |> pair_with_individual_translators() |> Utils.combine_nested_list() do
      assignments
      |> Enum.min_by(&slowest_assignee_in_group/1)
      |> Enum.map(fn {target_language, %{id: translator_id}} ->
        %{translator_id: translator_id, translation_project_id: project.id, target_language: target_language}
      end)
    else
      _ -> nil
    end
  end

  defp get_compatible_translator_data(%TranslationProject{
         target_languages: target_languages,
         estimated_hours_per_language: project_hours_per_language,
         deadline_in_days: deadline_in_days
       }) do
    Translator
    |> where([tl], fragment("? && ?", tl.known_languages, ^target_languages))
    |> join(:left, [tl], t in Task, tl.id == t.translator_id)
    |> join(:left, [tl, t], p in TranslationProject, t.translation_project_id == p.id)
    |> group_by([tl, _, _], tl.id)
    |> select([tl, _t, p], %{
      id: tl.id,
      known_languages: tl.known_languages,
      hours_per_day: tl.hours_per_day,
      assigned_hours: sum(p.estimated_hours_per_language)
    })
    |> Repo.all()
    |> Enum.map(fn %{hours_per_day: hours_per_day, assigned_hours: assigned_hours} = translator ->
      translator |> Map.put(:days_to_complete, (assigned_hours || 0) + project_hours_per_language / hours_per_day)
    end)
    |> Enum.filter(fn %{days_to_complete: days_to_complete} -> days_to_complete <= deadline_in_days end)
  end

  defp lacks_translators?({_, []}), do: true
  defp lacks_translators?({_, _}), do: false

  defp pair_with_individual_translators(language_translator_groups) do
    language_translator_groups
    |> Enum.map(fn {language, translators} ->
      translators |> Enum.map(fn translator_data -> {language, translator_data} end)
    end)
  end

  defp slowest_assignee_in_group(assignment) do
    assignment
    |> Enum.group_by(fn {_, %{id: id}} -> id end)
    |> Enum.map(fn {_id, assignments} ->
      {_language, assignment} = assignments |> List.first()
      assignment[:days_to_complete]
    end)
    |> Enum.max()
  end
end
