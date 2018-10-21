defmodule Translations.Utils do
  @doc """
  Returns all possible permutations of nested lists, where 1 of X elements can be taken from the list.
  """
  @spec combine_nested_list(list) :: list
  def combine_nested_list([list]) when is_list(list), do: [list]
  def combine_nested_list(list) when is_list(list), do: do_combine_nested_list(list)

  def do_combine_nested_list([head_list | tail_lists]) when is_list(tail_lists) and tail_lists != [] do
    head_list
    |> Enum.reduce([], fn head, acc ->
      acc ++ (tail_lists |> do_combine_nested_list() |> Enum.map(fn tail -> List.wrap(head) ++ List.wrap(tail) end))
    end)
  end

  def do_combine_nested_list([last_language]) when is_list(last_language), do: last_language
  def do_combine_nested_list([]), do: []

  @doc """
  Returns a set-intersection of two lists, converted back to a list.

  Only works with elements where simple equality comparison will work.
  """
  @spec list_intersection(list, list) :: list
  def list_intersection(a, b) do
    a |> MapSet.new() |> MapSet.intersection(b |> MapSet.new()) |> MapSet.to_list()
  end
end
