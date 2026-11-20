defmodule AeMdw.CollectionTest do
  use ExUnit.Case

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Util

  require Model

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

    test "halts the streams it doesn't read to the end" do
      test_pid = self()

      streams =
        for {name, keys} <- [a: [1, 4, 7], b: [2, 5], c: [3, 6]] do
          Stream.resource(
            fn -> keys end,
            fn
              [] -> {:halt, []}
              [key | rest] -> {[key], rest}
            end,
            fn _rest -> send(test_pid, {:closed, name}) end
          )
        end

      merged = Collection.merge(streams, :forward)

      assert [1, 2, 3] == Enum.take(merged, 3)
      assert_received {:closed, :a}
      assert_received {:closed, :b}
      assert_received {:closed, :c}
      refute_received {:closed, _name}

      assert [1, 2, 3, 4, 5, 6, 7] == Enum.to_list(merged)
    end

    test "raises the error of a merged stream that fails" do
      height = Enum.random(1_000_000_000..9_999_999_999)
      write_blocks(height, 0..3)
      state = State.new()

      streams =
        for {first, last} <- [{0, 1}, {2, 3}] do
          state
          |> Collection.stream(Model.Block, :forward, {{height, first}, {height, last}}, nil)
          |> Stream.map(fn
            {^height, 1} -> raise "boom"
            key -> key
          end)
        end

      assert_raise RuntimeError, "boom", fn ->
        streams |> Collection.merge(:forward) |> Enum.to_list()
      end
    end
  end

  describe "stream/5" do
    test "returns the keys within the boundary, starting at the cursor" do
      height = Enum.random(1_000_000_000..9_999_999_999)
      write_blocks(height, 0..9)
      boundary = {{height, 2}, {height, 7}}

      for state <- [State.new(), State.new(MemStore.new(DbStore.new()))] do
        assert Enum.map(2..7, &{height, &1}) == stream_keys(state, :forward, boundary, nil)
        assert Enum.map(7..2//-1, &{height, &1}) == stream_keys(state, :backward, boundary, nil)

        assert Enum.map(4..7, &{height, &1}) ==
                 stream_keys(state, :forward, boundary, {height, 4})

        assert Enum.map(5..2//-1, &{height, &1}) ==
                 stream_keys(state, :backward, boundary, {height, 5})

        assert Enum.map(2..7, &{height, &1}) ==
                 stream_keys(state, :forward, boundary, {height, 0})

        assert [] == stream_keys(state, :forward, boundary, {height, 8})
      end
    end
  end

  describe "intersect/4" do
    test "returns the values every side holds, in both directions" do
      odds = [1, 3, 5, 7, 9]
      others = [2, 3, 4, 7, 8, 9]

      assert [3, 7, 9] == intersect([[odds], [others]], :forward, 0, 100)
      assert [9, 7, 3] == intersect([[odds], [others]], :backward, 100, 0)
      assert [1, 3, 5, 7, 9] == intersect([[odds]], :forward, 0, 100)
    end

    test "returns the values all of three sides hold" do
      sides = [[[1, 2, 3, 5, 8, 13]], [[2, 3, 5, 7, 11, 13]], [[1, 3, 5, 7, 9, 11, 13]]]

      assert [3, 5, 13] == intersect(sides, :forward, 0, 100)
      assert [13, 5, 3] == intersect(sides, :backward, 100, 0)
    end

    test "takes the union of the seek functions of a side" do
      assert [3, 5, 7] == intersect([[[1, 5], [3, 7]], [[3, 4, 5, 6, 7]]], :forward, 0, 100)
      assert [7, 5, 3] == intersect([[[1, 5], [3, 7]], [[3, 4, 5, 6, 7]]], :backward, 100, 0)
    end

    test "only returns the values from start to stop" do
      assert [3, 7] == intersect([[[1, 3, 7, 9]], [[1, 3, 7, 9]]], :forward, 3, 8)
      assert [7, 3] == intersect([[[1, 3, 7, 9]], [[1, 3, 7, 9]]], :backward, 7, 2)
      assert [] == intersect([[[1, 3, 7, 9]], [[1, 3, 7, 9]]], :forward, 10, 20)
    end

    test "returns nothing when a side is empty" do
      assert [] == intersect([[[]], [[1, 2, 3]]], :forward, 0, 100)
      assert [] == intersect([[[1, 2, 3]], [[], []]], :backward, 100, 0)
    end

    test "jumps over the values the other side doesn't hold" do
      seeks = :counters.new(1, [])

      every_int = fn from ->
        :counters.add(seeks, 1, 1)
        {:ok, from}
      end

      assert [7, 999_999] ==
               [[every_int], [seek([7, 999_999], :forward)]]
               |> Collection.intersect(:forward, 0, 1_000_000)
               |> Enum.to_list()

      assert :counters.get(seeks, 1) < 10
    end

    test "seeks a function again only once its value is passed, and never once it is exhausted" do
      seeks = :counters.new(2, [])

      counted = fn index, values ->
        seek_fn = seek(values, :forward)

        fn from ->
          :counters.add(seeks, index, 1)
          seek_fn.(from)
        end
      end

      every_int = fn from -> {:ok, from} end

      assert [5, 10, 20, 50] ==
               [[counted.(1, [50]), counted.(2, []), seek([5, 10, 20], :forward)], [every_int]]
               |> Collection.intersect(:forward, 0, 100)
               |> Enum.to_list()

      assert :counters.get(seeks, 1) == 2
      assert :counters.get(seeks, 2) == 1
    end

    test "stays lazy" do
      evens = fn from -> {:ok, from + rem(from, 2)} end
      threes = fn from -> {:ok, from + rem(3 - rem(from, 3), 3)} end

      assert [0, 6, 12] ==
               [[evens], [threes]]
               |> Collection.intersect(:forward, 0, 1_000_000_000_000)
               |> Enum.take(3)
    end
  end

  defp intersect(sides, direction, start, stop) do
    sides
    |> Enum.map(fn side -> Enum.map(side, &seek(&1, direction)) end)
    |> Collection.intersect(direction, start, stop)
    |> Enum.to_list()
  end

  defp seek(values, :forward), do: fn from -> find_value(values, &(&1 >= from)) end

  defp seek(values, :backward),
    do: fn from -> values |> Enum.reverse() |> find_value(&(&1 <= from)) end

  defp find_value(values, fun) do
    case Enum.find(values, fun) do
      nil -> :none
      value -> {:ok, value}
    end
  end

  defp stream_keys(state, direction, boundary, cursor) do
    state
    |> Collection.stream(Model.Block, direction, boundary, cursor)
    |> Enum.to_list()
  end

  defp write_blocks(height, mbis) do
    Enum.each(mbis, &Database.dirty_write(Model.Block, Model.block(index: {height, &1})))
    on_exit(fn -> Enum.each(mbis, &Database.dirty_delete(Model.Block, {height, &1})) end)
  end
end
