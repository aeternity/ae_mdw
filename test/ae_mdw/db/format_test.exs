defmodule AeMdw.Db.FormatTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Format

  describe "encode_raw_values/1" do
    test "formats a word" do
      assert %{
               "return" => %{
                 "type" => "tuple",
                 "value" => %{"word" => 123}
               }
             } == Format.encode_raw_values(%{return: %{type: :tuple, value: %{word: 123}}})
    end

    test "formats a map" do
      assert %{
               "return" => %{
                 "type" => "map",
                 "value" => %{"map" => %{"key" => "word", "value" => "string"}}
               }
             } ==
               Format.encode_raw_values(%{return: %{type: :map, value: {:map, :word, :string}}})
    end

    test "formats a list" do
      assert %{
               "return" => %{
                 "type" => "list",
                 "value" => %{"list" => [1, 2]}
               }
             } == Format.encode_raw_values(%{return: %{type: :list, value: {:list, [1, 2]}}})
    end

    test "formats a non-string binary to base64" do
      bin = :crypto.strong_rand_bytes(64)

      assert %{
               "return" => %{
                 "type" => "string",
                 "value" => Base.encode64(bin)
               }
             } ==
               Format.encode_raw_values(%{
                 return: %{
                   type: :string,
                   value: bin
                 }
               })
    end

    test "formats a return composed by tuple value" do
      assert %{
               "return" => %{
                 "type" => "tuple",
                 "value" => [
                   %{"type" => "typerep", "value" => %{"tuple" => []}},
                   %{"type" => "tuple", "value" => []}
                 ]
               }
             } ==
               Format.encode_raw_values(%{
                 return: %{
                   type: :tuple,
                   value: [
                     %{type: :typerep, value: {:tuple, []}},
                     %{type: :tuple, value: []}
                   ]
                 }
               })
    end
  end
end
