defmodule AeMdw.NodeTest do
  use ExUnit.Case

  import Mock

  alias AeMdw.Node

  describe "token_supply_delta/1" do
    test "returns 0 outside hardfork heights" do
      assert 0 == Node.token_supply_delta(123_456_789)
    end

    test "does not store a persistent term per height" do
      assert_no_memoized_calls(&Node.token_supply_delta/1, 100_000_001..100_000_100)
    end
  end

  describe "difficulty_to_hashrate/1" do
    test "converts difficulty with the default 3 minute mine rate" do
      assert 230_453 == Node.difficulty_to_hashrate(987_654_321_000)
    end

    test "does not store a persistent term per difficulty" do
      assert_no_memoized_calls(&Node.difficulty_to_hashrate/1, 900_000_000_001..900_000_000_100)
    end
  end

  describe "epoch_length/1" do
    test "does not keep returning an earlier error" do
      with_mocks [
        {:aec_chain_hc, [], [epoch_length: fn _epoch -> {:error, :chain_too_short} end]}
      ] do
        assert {:error, :chain_too_short} = Node.epoch_length(42)
      end

      with_mocks [{:aec_chain_hc, [], [epoch_length: fn _epoch -> {:ok, 10} end]}] do
        assert {:ok, 10} = Node.epoch_length(42)
      end
    end
  end

  # The first call memoizes the zero-arity helpers the function depends on.
  defp assert_no_memoized_calls(fun, args) do
    fun.(args.first)
    keys_before = node_persistent_term_keys()

    Enum.each(args, fun)

    assert node_persistent_term_keys() == keys_before
  end

  defp node_persistent_term_keys do
    for {{Node, _name, _args} = key, _value} <- :persistent_term.get(),
        into: MapSet.new(),
        do: key
  end
end
