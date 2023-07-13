defmodule AeMdw.Util.SortedTableTest do
  use ExUnit.Case

  alias AeMdw.Util.SortedTable

  test "next and prev returns key and value" do
    t =
      SortedTable.new()
      |> SortedTable.insert(:a, 2)
      |> SortedTable.insert(:c, 3)
      |> SortedTable.insert(:b, 4)

    iterate = fn t, cursor, it_func ->
      cursor
      |> Stream.unfold(fn cursor ->
        case :erlang.apply(SortedTable, it_func, [t, cursor]) do
          {:ok, k, v} -> {{k, v}, k}
          :none -> nil
        end
      end)
      |> Enum.to_list()
    end

    assert [{:a, 2}, {:b, 4}, {:c, 3}] = iterate.(t, nil, :next)
    assert [{:b, 4}, {:c, 3}] = iterate.(t, :a, :next)
    assert [{:a, 2}, {:b, 4}, {:c, 3}] = iterate.(t, :"1", :next)

    assert [{:c, 3}, {:b, 4}, {:a, 2}] = iterate.(t, nil, :prev)
    assert [{:b, 4}, {:a, 2}] = iterate.(t, :c, :prev)
    assert [{:c, 3}, {:b, 4}, {:a, 2}] = iterate.(t, :d, :prev)

    t =
      t
      |> SortedTable.delete(:b)
      |> SortedTable.insert(:c, 5)

    assert [{:a, 2}, {:c, 5}] = iterate.(t, nil, :next)
    assert [{:c, 5}] = iterate.(t, :a, :next)
    assert [{:a, 2}, {:c, 5}] = iterate.(t, :"1", :next)
    assert [] = iterate.(t, :d, :next)

    assert [{:c, 5}, {:a, 2}] = iterate.(t, nil, :prev)
    assert [{:a, 2}] = iterate.(t, :c, :prev)
    assert [{:c, 5}, {:a, 2}] = iterate.(t, :d, :prev)
    assert [] = iterate.(t, :"1", :prev)
  end

  test "lookup works after insert and delete" do
    t =
      SortedTable.new()
      |> SortedTable.insert(:f, 2)
      |> SortedTable.insert(:b, 4)
      |> SortedTable.insert(:c, 5)
      |> SortedTable.insert(:e, 5)
      |> SortedTable.insert(:c, 6)

    assert {:ok, 2} = SortedTable.lookup(t, :f)
    assert {:ok, 6} = SortedTable.lookup(t, :c)
    assert {:ok, 5} = SortedTable.lookup(t, :e)
    assert :not_found = SortedTable.lookup(t, :h)
    assert :not_found = SortedTable.lookup(SortedTable.delete(t, :b), :b)
  end
end
