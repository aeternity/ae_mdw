defmodule AeMdw.Db.Sync.BlockIndex do
  # credo:disable-for-this-file
  @moduledoc "fills :block table from backwards to get {height, nil} -> keyblock_hash"

  require AeMdw.Db.Model

  alias AeMdw.Db.Sync
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia

  import AeMdw.{Sigil, Util, Db.Util}

  @log_freq 10000

  ################################################################################

  def sync(max_height \\ :safe) do
    max_height = Sync.height(max_height)
    min_height = (max_kbi() || -1) + 1

    with true <- max_height >= min_height do
      header = :aec_chain.get_key_header_by_height(max_height) |> ok!
      hash = :aec_headers.hash_header(header) |> ok!
      syncer = &sync_key_header(~t[block], &1, &2)
      tracker = Sync.progress_logger(syncer, @log_freq, &log_msg/2)
      :mnesia.transaction(fn -> max_height..min_height |> Enum.reduce(hash, tracker) end)
    end

    max_kbi()
  end

  def min_kbi(), do: kbi(&first/1)
  def max_kbi(), do: kbi(&last/1)

  def clear(),
    do: :mnesia.clear_table(~t[block])

  ################################################################################

  defp sync_key_header(table, height, hash) do
    {:ok, kh} = :aec_chain.get_header(hash)
    ^height = :aec_headers.height(kh)
    :key = :aec_headers.type(kh)
    kb_model = Model.block(index: {height, -1}, hash: hash)
    Mnesia.write(table, kb_model)
    :aec_headers.prev_key_hash(kh)
  end

  defp kbi(f) do
    case f.(~t[block]) do
      :"$end_of_table" -> nil
      {kbi, -1} -> kbi
    end
  end

  defp log_msg(height, _hash),
    do: "syncing block index at #{height}"
end
