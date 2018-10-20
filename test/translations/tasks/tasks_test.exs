defmodule Translations.Tasks.TasksTest do
  use Translations.DataCase

  alias Translations.Tasks

  describe "find_translator/1" do
    test "returns translator matched by id" do
      translator = insert(:translator)
      assert Tasks.find_translator(translator.id) == translator
    end

    test "returns nil if no translator matched" do
      assert Tasks.find_translator(-1) == nil
    end
  end

  describe "find_translation_project/1" do
    test "returns project matched by id" do
      translation_project = insert(:translation_project)
      assert Tasks.find_translation_project(translation_project.id) == translation_project
    end

    test "returns nil if no project matched" do
      assert Tasks.find_translation_project(-1) == nil
    end
  end
end
