defmodule AeMdw.Sync.MutationsCache do
  @moduledoc """
  Keeps the already processed microblocks changes.
  """

  alias AeMdw.Db.Mutation

  @hashes_table :sync_hashes

  @typep hash :: AeMdw.Blocks.block_hash()

  @spec init() :: :ok
  def init do
    :ets.new(@hashes_table, [:named_table, :set, :public])
  end

  @spec get_mbs_mutations(hash()) :: {[Mutation.t()], AeMdw.Txs.txi()} | nil
  def get_mbs_mutations(mb_hash) do
    {time, result} =
      :timer.tc(fn ->
        case :ets.lookup(@hashes_table, mb_hash) do
          [{^mb_hash, mutations_txi}] -> mutations_txi
          [] -> nil
        end
      end)

    if div(time, 1000) > 10, do: IO.inspect(div(time, 1000), label: :mbs_lookup)

    result
  end

  @spec put_mbs_mutations(hash(), {[Mutation.t()], AeMdw.Txs.txi()}) :: :ok
  def put_mbs_mutations(mb_hash, mutations_txi) do
    :ets.insert(@hashes_table, {mb_hash, mutations_txi})
    :ok
  end

  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@hashes_table)
    :ok
  end
end
