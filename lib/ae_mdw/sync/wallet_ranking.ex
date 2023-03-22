defmodule AeMdw.Sync.WalletRanking do
  @moduledoc """
  Wallet balance ranking.
  """
  @table :rankex_table
  @eot :"$end_of_table"
  @rank_size 100

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @spec init() :: :ok
  def init do
    @table = :ets.new(@table, [:named_table, :ordered_set, :public])
    :ok
  end

  @spec insert(pubkey(), integer()) :: :ok
  def insert(pubkey, balance) do
    :ets.insert(@table, {{balance, pubkey}})
    :ok
  end

  @spec prune() :: :ok
  def prune do
    top = top_records()
    :ets.delete_all_objects(@table)
    :ets.insert(@table, top)
    :ok
  end

  @spec top_records() :: [{pubkey(), integer()}]
  def top_records do
    case :ets.select_reverse(@table, [{:_, [], [:"$_"]}], @rank_size) do
      {list, _cont} -> list
      @eot -> []
    end
  end
end
