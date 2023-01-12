defmodule AeMdw.Db.FormatTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Format

  describe "map_raw_values/2" do
    test "formats a return composed by tuple value" do
      formatter = fn
        x when is_number(x) -> x
        x when is_tuple(x) -> Tuple.to_list(x)
        x -> to_string(x)
      end

      assert %{
               "arguments" => %{"type" => "tuple", "value" => []},
               "function" => "init",
               "result" => "ok",
               "return" => %{
                 "type" => "tuple",
                 "value" => [
                   %{"type" => "typerep", "value" => [:tuple, []]},
                   %{"type" => "tuple", "value" => []}
                 ]
               }
             } ==
               Format.map_raw_values(
                 %{
                   arguments: %{type: :tuple, value: []},
                   function: "init",
                   result: :ok,
                   return: %{
                     type: :tuple,
                     value: [
                       %{type: :typerep, value: {:tuple, []}},
                       %{type: :tuple, value: []}
                     ]
                   }
                 },
                 formatter
               )
    end
  end
end
