defmodule Translations.Tasks.Task do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  alias Ecto.Changeset

  schema "tasks" do
    field(:target_language, :string, null: false)
    belongs_to(:translator, Translations.Tasks.Translator)
    belongs_to(:translation_project, Translations.Tasks.TranslationProject)
  end

  def changeset(struct, params) do
    struct
    |> Changeset.cast(params, [:target_language, :translator_id, :translation_project_id])
    |> Changeset.validate_required(:translator_id)
    |> Changeset.validate_required(:translation_project_id)
    |> Changeset.assoc_constraint(:translator)
    |> Changeset.assoc_constraint(:translation_project)
    |> Changeset.unique_constraint(:target_language, [:translation_project_id, :translator_id, :target_language])
  end
end
