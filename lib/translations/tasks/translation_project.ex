defmodule Translations.Tasks.TranslationProject do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "projects" do
    field(:original_language, :string)
    field(:target_languages, {:array, :string})
    field(:estimated_hours_per_language, :float)
    field(:deadline_in_days, :integer)

    has_many(:tasks, Translations.Tasks.Task)
  end
end
