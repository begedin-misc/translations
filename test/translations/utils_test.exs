defmodule Translations.UtilsTest do
  use ExUnit.Case, async: true

  alias Translations.Utils

  describe "combine_nested_list/1" do
    test "works on blank list" do
      assert Utils.combine_nested_list([]) == []
    end

    test "returns single nested list unmodified" do
      assert Utils.combine_nested_list([[1, 2, 3]]) == [[1, 2, 3]]
    end

    test "combines two nested lists correctly" do
      assert Utils.combine_nested_list([[1, 2], [3, 4]]) == [[1, 3], [1, 4], [2, 3], [2, 4]]
    end

    test "combines two nested lists of different lengths correctly" do
      assert Utils.combine_nested_list([[1, 2], [3, 4, 5]]) == [[1, 3], [1, 4], [1, 5], [2, 3], [2, 4], [2, 5]]
    end

    test "combines longer nested lists correclty" do
      assert Utils.combine_nested_list([[1, 2], [3, 4], [5, 6]]) ==
               [[1, 3, 5], [1, 3, 6], [1, 4, 5], [1, 4, 6], [2, 3, 5], [2, 3, 6], [2, 4, 5], [2, 4, 6]]
    end

    test "combines longer nested lists of different lengths correctly" do
      assert Utils.combine_nested_list([[1, 2], [3], [5, 6]]) == [[1, 3, 5], [1, 3, 6], [2, 3, 5], [2, 3, 6]]
    end
  end

  describe "list_intersection/2" do
    test "works with blank lists" do
      assert Utils.list_intersection([], []) == []
    end

    test "works with blank lists on the left" do
      assert Utils.list_intersection([], [1]) == []
    end

    test "works with blank lists on the right" do
      assert Utils.list_intersection([1], []) == []
    end

    test "returns common elements in two lists" do
      assert Utils.list_intersection([1, 2], [2, 3]) == [2]
      assert Utils.list_intersection([2, 1], [2, 3]) == [2]
      assert Utils.list_intersection([1, 2, 3], [2, 3, 4]) == [2, 3]
      assert Utils.list_intersection([1, 3, 2], [3, 4, 2]) == [2, 3]
    end

    test "eliminates duplicates" do
      assert Utils.list_intersection([1, 2, 2], [2, 2, 3]) == [2]
    end
  end
end
