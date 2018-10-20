defmodule Translations.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Translations.Repo

  # Random enough for test purposes.
  # We test specific cases by providing values manually
  @language_sets [~w(EN ES), ~w(GE ES), ~w(HR IT), ~w(EN IT), ~w(EN GE)]

  def translator_factory do
    %Translations.Tasks.Translator{
      name: Faker.Name.name(),
      hours_per_day: Faker.Util.pick([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]),
      known_languages: Faker.Util.pick(@language_sets)
    }
  end

  def translation_project_factory do
    %Translations.Tasks.TranslationProject{
      original_language: Faker.Util.pick(~w(EN ES GE HR IT)),
      target_languages: Faker.Util.pick(@language_sets),
      estimated_hours_per_language: Faker.Util.pick([2.0, 4.0, 8.0, 12.0, 16.0]),
      deadline_in_days: Faker.Util.pick([1, 2, 3, 4, 5])
    }
  end

  def task_factory do
    %Translations.Tasks.Task{
      target_language: Faker.Util.pick(~w(EN ES GE HR IT)),
      translation_project: build(:translation_project),
      translator: build(:translator)
    }
  end
end
