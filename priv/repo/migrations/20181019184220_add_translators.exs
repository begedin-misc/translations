defmodule Translations.Repo.Migrations.AddTranslators do
  use Ecto.Migration

  def change do
    create table(:translators) do
      add(:name, :string)
      add(:hours_per_day, :float)
      add(:known_languages, {:array, :string})
    end
  end
end
