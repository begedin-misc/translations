defmodule Translations.Repo.Migrations.AddTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add(:translation_project_id, references(:projects))
      add(:translator_id, references(:translators))
      add(:target_language, :string, null: false)
    end

    create(index(:tasks, [:translation_project_id, :translator_id, :target_language], unique: true))
  end
end
