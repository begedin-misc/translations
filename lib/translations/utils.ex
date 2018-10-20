defmodule Translations.Utils do
  def combine_nested_list([head_list | tail_lists]) when is_list(tail_lists) and tail_lists != [] do
    tail_combinations = tail_lists |> combine_nested_list()

    head_list
    |> Enum.reduce([], fn head, acc -> acc ++ (tail_combinations |> Enum.map(fn tail -> [head] ++ tail end)) end)
  end

  def combine_nested_list([last_language | rest]) when is_list(last_language) and rest == [], do: [last_language]
end
