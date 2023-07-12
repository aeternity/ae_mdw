defmodule AeMdw.Sync.MutationsCache do
  @moduledoc """
  Keeps the already processed microblocks changes.
  """

  alias AeMdw.Db.Mutation
  alias AeMdw.EtsCache

  @hashes_table :sync_hashes
  @expiration_minutes 120

  @typep hash :: AeMdw.Blocks.block_hash()

  @spec init() :: :ok
  def init do
    EtsCache.new(@hashes_table, @expiration_minutes)
  end

  @spec get_mbs_mutations(hash()) :: {[Mutation.t()], AeMdw.Txs.txi()} | nil
  def get_mbs_mutations(mb_hash) do
    with {mutations_txi, _time} <- EtsCache.get(@hashes_table, mb_hash) do
      mutations_txi
    end
  end

  @spec put_mbs_mutations(hash(), {[Mutation.t()], AeMdw.Txs.txi()}) :: :ok
  def put_mbs_mutations(mb_hash, mutations_txi) do
    EtsCache.put(@hashes_table, mb_hash, mutations_txi)
    :ok
  end
end
