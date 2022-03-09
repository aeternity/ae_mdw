defmodule AeMdw.Db.Sync.BlockIndex do
  # credo:disable-for-this-file
  @moduledoc "fills :block table from backwards to get {height, nil} -> keyblock_hash"

  require AeMdw.Db.Model

  alias AeMdw.Db.Sync
  alias AeMdw.Db.Model
  alias AeMdw.Database
  # alias AeMdw.Db.WriteTxnMutation
  alias AeMdw.Log

  import AeMdw.Util

  @log_freq 10000

  ################################################################################

  def sync(max_height \\ :safe) do
    max_height = Sync.height(max_height)
    min_height = (max_kbi() || -1) + 1

    if max_height >= min_height do
      header = :aec_chain.get_key_header_by_height(max_height) |> ok!
      initial_hash = :aec_headers.hash_header(header) |> ok!

      {_m_block_list, _} =
        Enum.reduce(max_height..min_height, {[], initial_hash}, fn height, {m_block_list, hash} ->
          if rem(height, @log_freq) == 0, do: Log.info("syncing block index at #{height}")

          {m_key_block, prev_hash} = sync_key_header(height, hash)

          {[m_key_block | m_block_list], prev_hash}
        end)

      # m_block_list
      # |> Enum.map(&WriteTxnMutation.new(Model.Block, &1))
      # |> Database.commit()
    end

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

    {kb_model, :aec_headers.prev_key_hash(kh)}
  end
end
