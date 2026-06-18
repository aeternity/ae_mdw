defmodule AeMdwWeb.GraphQL.Resolvers.HelpersTest do
  use ExUnit.Case, async: true

  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @max_gen 999_999_999

  describe "make_scope/1" do
    test "both bounds given, from < to → ascending gen range" do
      assert {:gen, 50..100} = Helpers.make_scope(%{from_height: 50, to_height: 100})
    end

    test "both bounds given, from > to → normalised to ascending range" do
      assert {:gen, 50..100} = Helpers.make_scope(%{from_height: 100, to_height: 50})
    end

    test "both bounds equal → single-block range" do
      assert {:gen, 77..77} = Helpers.make_scope(%{from_height: 77, to_height: 77})
    end

    test "only from_height → open-ended upper range via sentinel" do
      assert {:gen, 200..@max_gen} = Helpers.make_scope(%{from_height: 200})
    end

    test "only from_height = 0 → sentinel range from genesis" do
      assert {:gen, 0..@max_gen} = Helpers.make_scope(%{from_height: 0})
    end

    test "only to_height → range from genesis to given height" do
      assert {:gen, 0..300} = Helpers.make_scope(%{to_height: 300})
    end

    test "only to_height = 0 → single genesis range" do
      assert {:gen, 0..0} = Helpers.make_scope(%{to_height: 0})
    end

    test "neither height given → nil (no scope restriction)" do
      assert nil == Helpers.make_scope(%{})
    end

    test "unrelated args ignored → nil" do
      assert nil == Helpers.make_scope(%{limit: 10, direction: :forward})
    end

    test "from > to range is always ascending (first <= last)" do
      {:gen, first..last//_} = Helpers.make_scope(%{from_height: 999, to_height: 1})
      assert first <= last
    end
  end

  describe "pagination_args_with_scope/1" do
    test "includes scope from from_height and to_height" do
      args = %{from_height: 10, to_height: 20, limit: 5, direction: :forward}
      %{scope: scope, pagination: {dir, _, lim, _}} = Helpers.pagination_args_with_scope(args)
      assert scope == {:gen, 10..20}
      assert dir == :forward
      assert lim == 5
    end

    test "scope is nil when no height args given" do
      %{scope: scope} = Helpers.pagination_args_with_scope(%{})
      assert scope == nil
    end

    test "reversed from/to is normalised" do
      %{scope: {:gen, first..last//_}} =
        Helpers.pagination_args_with_scope(%{from_height: 100, to_height: 10})

      assert first == 10
      assert last == 100
    end
  end

  describe "pagination_args_all_with_scope/1" do
    test "includes scope from to_height only" do
      %{scope: scope} = Helpers.pagination_args_all_with_scope(%{to_height: 50})
      assert scope == {:gen, 0..50}
    end

    test "includes scope from from_height only" do
      %{scope: {:gen, first..last//_}} =
        Helpers.pagination_args_all_with_scope(%{from_height: 42})

      assert first == 42
      assert last == @max_gen
    end
  end
end
