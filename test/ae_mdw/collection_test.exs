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
