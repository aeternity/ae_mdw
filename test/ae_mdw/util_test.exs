defmodule AeMdw.UtilTest do
  use ExUnit.Case

  alias AeMdw.Util

  describe "build_gen_pagination/5" do
    test "when forward and range_first exceeds last_gen, it returns error" do
      assert :error = Util.build_gen_pagination(nil, :forward, {400, 500}, 10, 300)
    end

    test "when backward and range_first exceeds last_gen, it returns error" do
      assert :error = Util.build_gen_pagination(nil, :backward, {200, 500}, 10, 100)
    end

    test "when limit exceeds last gen, it returns results up to the valid point" do
      assert {:ok, nil, range, nil} =
               Util.build_gen_pagination(nil, :forward, {400, 450}, 20, 409)

      assert ^range = Range.new(400, 409)
    end

    test "when cursor is outside last_gen, it returns error" do
      assert :error = Util.build_gen_pagination(500, :forward, {400, 500}, 20, 400)
    end

    test "when cursor + length is outside last_gen, it returns up to the valid point" do
      assert {:ok, 380, range, nil} = Util.build_gen_pagination(400, :forward, {0, 500}, 20, 410)
      assert ^range = Range.new(400, 410)
    end
  end
end
