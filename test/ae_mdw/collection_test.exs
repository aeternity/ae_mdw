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
end
