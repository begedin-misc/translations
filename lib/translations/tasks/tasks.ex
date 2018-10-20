defmodule Translations.Tasks do
  alias Translations.{Tasks.Translator, Tasks.TranslationProject, Tasks.Task, Repo, Utils}
  alias Ecto.Changeset

  import Ecto.Query

  def find_translator(id), do: Translator |> Repo.get(id)

  def find_translation_project(id), do: TranslationProject |> Repo.get(id)

  def assign_translator(%TranslationProject{} = translation_project, %Translator{} = translator) do
    %Task{}
    |> Changeset.cast(%{}, [])
    |> Changeset.put_assoc(:translator, translator)
    |> Changeset.put_assoc(:translation_project, translation_project)
    |> pick_language(translator, translation_project)
    |> Changeset.validate_required(:target_language)
    |> Repo.insert()
  end

  def assign_translators(%TranslationProject{} = project) do
    project
    |> Repo.preload(:tasks)
    |> assign_tasks()
    |> Repo.update()
  end

  def assign_all() do
    projects =
      TranslationProject
      |> Repo.all()
      |> Repo.preload(:tasks)
      |> Enum.sort_by(&TranslationProject.get_hours_needed/1)

    projects |> iteratively_assign_tasks()
  end

  defp iteratively_assign_tasks(projects) do
    [project | rest] = projects
    first_result = project |> assign_translators()
    do_iteratively_assign_tasks(rest, first_result)
  end

  defp do_iteratively_assign_tasks(unassigned_projects, last_result, assigned_count \\ 1)

  defp do_iteratively_assign_tasks([project | rest], {:ok, _prev_assigned_project}, assigned_count) do
    do_iteratively_assign_tasks(rest, project |> assign_translators(), assigned_count + 1)
  end

  defp do_iteratively_assign_tasks(_not_yet_assigned, {:error, _error}, assigned_count), do: assigned_count
  defp do_iteratively_assign_tasks([], _last_result, assigned_count), do: assigned_count

  def get_compatible_translators_grouped_by_target_languages(%TranslationProject{} = project) do
    translators_data = get_compatible_translator_data(project)
    project.target_languages |> Enum.map(&pair_with_compatible_translators(&1, translators_data))
  end

  defp assign_tasks(%TranslationProject{} = project) do
    changeset = project |> Changeset.cast(%{}, [])

    language_data = project |> get_compatible_translators_grouped_by_target_languages()

    if language_data |> Enum.any?(&lacks_translators?/1) do
      changeset |> Changeset.add_error(:tasks, "Not enough compatible translators to complete project in time")
    else
      assignments = language_data |> pair_with_individual_translators() |> Utils.combine_nested_list()

      if assignments == [] do
        changeset |> Changeset.add_error(:tasks, "Not enough compatible translators to complete project in time")
      else
        assignment = assignments |> Enum.min_by(&slowest_assignee_in_group/1)

        task_params =
          assignment
          |> Enum.map(fn {target_language, {translator_id, _, _, _}} ->
            %{translator_id: translator_id, translation_project_id: project.id, target_language: target_language}
          end)

        changeset |> Changeset.cast(%{tasks: task_params}, []) |> Changeset.cast_assoc(:tasks)
      end
    end
  end

  def build_info(%TranslationProject{} = project) do
    project = project |> Repo.preload(tasks: :translator)

    translators =
      project.tasks
      |> Enum.reduce(%{}, fn %{target_language: target_language, translator: translator}, acc ->
        acc |> Map.put(target_language, translator |> Map.take([:id, :name, :hours_per_day, :known_languages]))
      end)

    slowest_translator_completion_time =
      translators
      |> Enum.reduce(0, fn {_language, %{hours_per_day: hours_per_day}}, max_days_needed ->
        days_needed = project.estimated_hours_per_language / hours_per_day
        if days_needed > max_days_needed, do: days_needed, else: max_days_needed
      end)

    project
    |> Map.take([:id, :original_language, :target_languages, :estimated_hours_per_language, :deadline_in_days])
    |> Map.merge(%{translators: translators, will_complete_in_days: slowest_translator_completion_time})
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
    |> select([tl, _t, p], {tl.id, tl.known_languages, tl.hours_per_day, sum(p.estimated_hours_per_language)})
    |> Repo.all()
    |> Enum.map(fn {id, known_languages, hours_per_day, hours_assigned} ->
      days_to_complete = (hours_assigned || 0) + project_hours_per_language / hours_per_day
      {id, known_languages, hours_per_day, days_to_complete}
    end)
    |> Enum.filter(fn {_id, _known_languages, _per_day, days_to_complete} -> days_to_complete < deadline_in_days end)
  end

  defp pair_with_compatible_translators(language, translators_data) do
    {language, translators_data |> Enum.filter(fn {_id, known_languages, _, _} -> language in known_languages end)}
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
    |> Enum.group_by(fn {_, {id, _, _, _}} -> id end)
    |> Enum.map(fn {_id, assignments} -> assignments |> Enum.reduce(0, fn {_, {_, _, _, x}}, acc -> acc + x end) end)
    |> Enum.max()
  end

  defp pick_language(
         %Changeset{} = changeset,
         %Translator{known_languages: known_languages} = translator,
         %TranslationProject{original_language: original_language, target_languages: target_languages} = project
       ) do
    with :language_known <- known_status(translator, original_language),
         :deadline_reachable <- deadline_status(translator, project),
         compatible_languages when compatible_languages != [] <-
           get_compatible_languages(known_languages, target_languages),
         available_languages when available_languages != [] <- get_available_languages(project, compatible_languages) do
      changeset |> Changeset.put_change(:target_language, available_languages |> List.first())
    else
      :language_unknown ->
        changeset |> Changeset.add_error(:target_language, "Original language not known by translator.")

      :deadline_unreachable ->
        changeset |> Changeset.add_error(:target_language, "Translator cannot reach deadline.")

      [] ->
        changeset
        |> Changeset.add_error(:target_language, "Available languages incompatible with translators known languages.")
    end
  end

  defp known_status(%Translator{known_languages: known_languages}, original_language) do
    if original_language in known_languages, do: :language_known, else: :language_unknown
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

  defp get_compatible_languages(known_list, target_list) do
    known_set = known_list |> MapSet.new()
    target_set = target_list |> MapSet.new()
    known_set |> MapSet.intersection(target_set) |> MapSet.to_list()
  end

  def get_available_languages(%TranslationProject{id: id}, compatible_languages) do
    taken_languages =
      Task
      |> where([t], t.translation_project_id == ^id)
      |> select([t], t.target_language)
      |> Repo.all()
      |> List.flatten()
      |> MapSet.new()

    compatible_set = compatible_languages |> MapSet.new()
    compatible_set |> MapSet.difference(taken_languages) |> MapSet.to_list()
  end
end
