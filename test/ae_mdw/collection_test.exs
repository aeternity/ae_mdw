defmodule AeMdw.CollectionTest do
  use ExUnit.Case

  alias AeMdw.Collection
  alias AeMdw.Util

  test "generate key boundaries" do
    assert {{:test}, {:test}} == Collection.generate_key_boundary({:test})

    assert {{:test, Util.min_int()}, {:test, Util.max_int()}} ==
             Collection.generate_key_boundary({:test, Collection.integer()})

    assert {{:test, Util.min_int(), 0}, {:test, Util.max_int(), Util.max_int()}} ==
             Collection.generate_key_boundary(
               {:test, Collection.integer(), Collection.pos_integer()}
             )

    assert {{Util.min_256bit_int(), Util.min_bin()}, {Util.max_int(), Util.max_256bit_bin()}} ==
             Collection.generate_key_boundary({Collection.integer_256bit(), Collection.binary()})

    assert {{:test1, :test2, Util.min_int()}, {:test1, :test2, Util.max_int()}} ==
             Collection.generate_key_boundary({:test1, :test2, Collection.integer()})
  end

  describe "merge/2" do
    test "merges sorted streams without dups" do
      assert [1, 2, 3, 4] == Enum.to_list(Collection.merge([[1, 2, 4], [2, 3, 4], []], :forward))
      assert [4, 3, 2, 1] == Enum.to_list(Collection.merge([[4, 2, 1], [4, 3, 2]], :backward))
    end

    test "removes dups that are not next to each other" do
      assert [1, 2, 3] == Enum.to_list(Collection.merge([[1, 3, 2], [2]], :forward))
      assert [3, 2, 1] == Enum.to_list(Collection.merge([[3, 1, 2], [2]], :backward))
    end

    test "stays lazy on infinite streams" do
      evens = Stream.iterate(0, &(&1 + 2))
      threes = Stream.iterate(0, &(&1 + 3))

      assert [0, 2, 3, 4, 6, 8] == [evens, threes] |> Collection.merge(:forward) |> Enum.take(6)
    end
  end
end
