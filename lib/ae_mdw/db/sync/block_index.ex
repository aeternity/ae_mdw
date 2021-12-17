defmodule AeMdw.Db.Sync.BlockIndex do
  @moduledoc """
  Fills Model.Block table from backwards to save the key block hashes
  """

  alias AeMdw.Db.Model
  alias AeMdw.Node.Chain
  alias AeMdw.Log

  require Model

  import AeMdw.Db.Util
  import AeMdw.Sigil

  @log_freq 10_000

  @spec sync(Chain.height()) :: Chain.height()
  def sync(max_height) when is_integer(max_height) do
    max_height = Chain.checked_height(max_height)
    min_height = (max_kbi() || -1) + 1

    with true <- max_height >= min_height do
      {:ok, header} = :aec_chain.get_key_header_by_height(max_height)
      {:ok, hash} = :aec_headers.hash_header(header)

      :mnesia.transaction(fn -> sync_range(max_height..min_height, hash) end)
    end

    max_kbi()
  end

  @spec max_kbi() :: Chain.height() | nil
  def max_kbi(), do: kbi(&last/1)

  @spec clear() :: :ok
  def clear(),
    do: :mnesia.clear_table(~t[block])

  #
  # Private functions
  #
  defp sync_range(max_height..min_height, block_hash) do
    Enum.reduce(max_height..min_height, block_hash, fn height, next_hash ->
      if rem(height, @log_freq) == 0, do: Log.info("syncing block index at #{height}")

      sync_key_header(~t[block], height, next_hash)
    end)
  end

  defp sync_key_header(table, height, hash) do
    {:ok, kh} = :aec_chain.get_header(hash)
    ^height = :aec_headers.height(kh)
    :key = :aec_headers.type(kh)
    kb_model = Model.block(index: {height, -1}, hash: hash)
    :mnesia.write(table, kb_model, :write)
    :aec_headers.prev_key_hash(kh)
  end

  defp kbi(f) do
    case f.(~t[block]) do
      :"$end_of_table" -> nil
      {kbi, -1} -> kbi
    end
  end
end
