defmodule AeMdw.Util.GbTreeTest do
  use ExUnit.Case

  alias AeMdw.Util.GbTree

  test "it behaves like a sorted key-value store" do
    tree1 = GbTree.new()

    assert tree1 == GbTree.delete(tree1, :a)

    tree2 =
      tree1
      |> GbTree.insert(:a, 1)
      |> GbTree.insert(:c, 2)
      |> GbTree.insert(:b, 2)

    assert [{:a, 1}, {:b, 2}, {:c, 2}] = tree2 |> GbTree.stream_forward() |> Enum.to_list()
    assert [{:b, 2}, {:c, 2}] = tree2 |> GbTree.stream_forward(:b) |> Enum.to_list()
    assert [{:a, 1}, {:b, 2}, {:c, 2}] = tree2 |> GbTree.stream_forward(:"1") |> Enum.to_list()

    assert [{:c, 2}, {:b, 2}, {:a, 1}] = tree2 |> GbTree.stream_backward() |> Enum.to_list()
    assert [{:b, 2}, {:a, 1}] = tree2 |> GbTree.stream_backward(:b) |> Enum.to_list()
    assert [{:c, 2}, {:b, 2}, {:a, 1}] = tree2 |> GbTree.stream_backward(:d) |> Enum.to_list()

    tree3 =
      tree2
      |> GbTree.insert(:f, 3)
      |> GbTree.insert(:b, 7)
      |> GbTree.insert(:e, 4)
      |> GbTree.insert(:d, 5)
      |> GbTree.delete(:b)

    assert {:ok, 2} = GbTree.lookup(tree3, :c)
    assert {:ok, 3} = GbTree.lookup(tree3, :f)
    assert :not_found = GbTree.lookup(tree3, :h)

    assert {:ok, :c, 2} = GbTree.next(tree3, :a)
    assert {:ok, :d, 5} = GbTree.next(tree3, :c)
    assert {:ok, :a, 1} = GbTree.next(tree3, nil)

    assert {:ok, :a, 1} = GbTree.prev(tree3, :c)
    assert {:ok, :f, 3} = GbTree.prev(tree3, nil)
    assert {:ok, :f, 3} = GbTree.prev(tree3, :z)
  end
end
