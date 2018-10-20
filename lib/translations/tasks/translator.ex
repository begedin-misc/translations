defmodule Translations.Tasks.Translator do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "translators" do
    field(:name, :string)
    field(:hours_per_day, :float)
    field(:known_languages, {:array, :string})
  end
end
