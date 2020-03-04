defmodule AeMdw.Db.Sync.BlockIndex do

  @moduledoc "fills :block table from backwards to get {height, nil} -> keyblock_hash"

  require AeMdw.Db.Model

  alias AeMdw.Db.{Model, Sync}

  import AeMdw.Sigil

  @log_freq 10000
  def sync() do
    case :aec_chain.top_key_block() do
      {:ok, {:key_block, top_header}} ->
        {:ok, hash} = :aec_headers.hash_header(top_header)
        height  = :aec_headers.height(top_header)
        syncer  = &sync_key_header(~t[block], &1, &2)
        tracker = Sync.progress_logger(syncer, @log_freq, &log_msg/2)
        height..0 |> Enum.reduce(hash, tracker)
      :error ->
        {:error, :no_top_key_block}
    end
  end

  defp sync_key_header(table, height, hash) do
    {:ok, kh} = :aec_chain.get_header(hash)
    ^height = :aec_headers.height(kh)
    :key    = :aec_headers.type(kh)
    write_index(table, height, hash)
    :aec_headers.prev_key_hash(kh)
  end

  defp write_index(table, height, hash),
    do: table |> :mnesia.dirty_write(Model.block([index: {height, -1}, hash: hash]))

  defp log_msg(height, _hash),
    do: "syncing block index at #{height}"

end
