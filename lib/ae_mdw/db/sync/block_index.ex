defmodule AeMdw.Db.Sync.BlockIndex do
  # credo:disable-for-this-file
  @moduledoc "fills :block table from backwards to get {height, nil} -> keyblock_hash"

  require AeMdw.Db.Model

  alias AeMdw.Db.Sync
  alias AeMdw.Db.Model
  alias AeMdw.Database

  import AeMdw.Util

  @log_freq 10000

  ################################################################################

  def sync(max_height \\ :safe) do
    max_height = Sync.height(max_height)
    min_height = (max_kbi() || -1) + 1

    if max_height >= min_height do
      header = :aec_chain.get_key_header_by_height(max_height) |> ok!
      hash = :aec_headers.hash_header(header) |> ok!
      syncer = &sync_key_header(&1, &2)
      tracker = Sync.progress_logger(syncer, @log_freq, &commit_and_log/2)

      Enum.reduce(max_height..min_height, hash, tracker)
    end

    Database.commit()

    max_kbi()
  end

  def min_kbi() do
    case Database.first_key(Model.Block) do
      :none -> nil
      {:ok, {kbi, _mbi}} -> kbi
    end
  end

  def max_kbi() do
    case Database.last_key(Model.Block) do
      :none -> nil
      {:ok, {kbi, _mbi}} -> kbi
    end
  end

  ################################################################################

  defp sync_key_header(height, hash) do
    {:ok, kh} = :aec_chain.get_header(hash)
    ^height = :aec_headers.height(kh)
    :key = :aec_headers.type(kh)
    kb_model = Model.block(index: {height, -1}, hash: hash)
    Database.write(Model.Block, kb_model)
    :aec_headers.prev_key_hash(kh)
  end

  defp commit_and_log(height, _hash) do
    Database.commit()
    "syncing block index at #{height}"
  end
end
