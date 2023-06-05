defmodule AeMdwWeb.Websocket.BroadcasterCache do
  @moduledoc """
  Keeps broadcasted block hashes and generation txs count.
  """

  alias AeMdw.EtsCache

  @hashes_table :broadcast_hashes
  @txs_count_table :broadcast_txs_count
  @expiration_minutes 120

  @typep hash :: AeMdw.Blocks.block_hash()
  @typep type_hash :: tuple()

  @spec init() :: :ok
  def init do
    EtsCache.new(@hashes_table, @expiration_minutes)
    EtsCache.new(@txs_count_table, @expiration_minutes)
  end

  @spec already_processed?(type_hash()) :: boolean()
  def already_processed?(type_hash), do: EtsCache.member(@hashes_table, type_hash)

  @spec set_processed(type_hash()) :: true
  def set_processed(type_hash), do: EtsCache.put(@hashes_table, type_hash, true)

  @spec get_txs_count(hash()) :: non_neg_integer() | nil
  def get_txs_count(kb_hash) do
    with {txs_count, _tm} <- EtsCache.get(@txs_count_table, kb_hash) do
      txs_count
    end
  end

  @spec put_txs_count(hash(), non_neg_integer()) :: :ok
  def put_txs_count(kb_hash, count) do
    EtsCache.put(@txs_count_table, kb_hash, count)
    :ok
  end
end
