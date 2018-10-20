defmodule Translations.Repo.Migrations.AddProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add(:original_language, :string, null: false)
      add(:target_languages, {:array, :string})
      add(:deadline_in_days, :integer)
      add(:estimated_hours_per_language, :float)
    end
  end
end
