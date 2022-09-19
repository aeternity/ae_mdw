defmodule AeMdw.UtilTest do
  use ExUnit.Case

  alias AeMdw.Util

  describe "terms comparision" do
    test "result in integer asc order" do
      # min_int is a shorthand for min_nonbigint_integer
      assert Util.min_256bit_int() < Util.min_int()
      assert Util.min_int() < 576_460_752_303_423_488 and 576_460_752_303_423_488 < Util.max_int()
    end

    test "result in binary asc order" do
      assert Util.min_bin() < Util.max_name_bin()
      assert Util.max_name_bin() < Util.max_256bit_bin()
    end
  end

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

    test "when backward and previous is outside range, it returns nil prev" do
      assert {:ok, nil, range, 480} = Util.build_gen_pagination(nil, :backward, {0, 500}, 20, 500)
      assert ^range = Range.new(500, 481)
    end
  end
end
