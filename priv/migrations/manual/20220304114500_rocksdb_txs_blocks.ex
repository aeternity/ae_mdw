defmodule AeMdw.Migrations.RocksdbTxsBlocks  do
  @moduledoc """
  Copies all records from mnesia Model.Tx and Model.Block to mdw RocksDB.
  """
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF

  @spec run() :: :ok
  def run do
    Model.Block
    |> :mnesia.dirty_all_keys()
    |> Enum.each(fn bi ->
      [m_block] = :mnesia.dirty_read(Model.Block, bi)
      RocksDbCF.dirty_put(Model.Block, m_block)
    end)

    first_txi = case Database.last_key(Model.Tx) do
      :none -> :mnesia.dirty_first(Model.Tx)
      {:ok, txi} -> txi
    end

    last_txi = :mnesia.dirty_last(Model.Tx)

    Enum.each(first_txi..last_txi, fn txi ->
      [m_tx] = :mnesia.dirty_read(Model.Tx, txi)
      RocksDbCF.dirty_put(Model.Tx, m_tx)
    end)

    :ok
  end
end
