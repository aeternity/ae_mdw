defmodule AeMdw.Node.DbTest do
  use ExUnit.Case

  import Mock

  alias AeMdw.Node.Db

  describe "get_next_hash/2" do
    test "returns the block after the micro block reading headers only" do
      [kb_hash, mb_hash0, mb_hash1, mb_hash2, next_kb_hash] =
        for _i <- 1..5, do: :crypto.strong_rand_bytes(32)

      headers = %{
        next_kb_hash => {:key, mb_hash2},
        mb_hash2 => {:micro, mb_hash1},
        mb_hash1 => {:micro, mb_hash0},
        mb_hash0 => {:micro, kb_hash},
        kb_hash => {:key, <<0::256>>}
      }

      with_mocks [
        {:aec_db, [], [get_header: &Map.fetch!(headers, &1)]},
        {:aec_headers, [], [type: &elem(&1, 0), prev_hash: &elem(&1, 1)]}
      ] do
        assert mb_hash1 == Db.get_next_hash(next_kb_hash, 0)
        assert mb_hash2 == Db.get_next_hash(next_kb_hash, 1)
        assert next_kb_hash == Db.get_next_hash(next_kb_hash, 2)
      end
    end
  end
end
