defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts the keys of active and inactive Names and Oracles
  """

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @active_names_table :active_names
  @active_oracles_table :active_oracles
  @inactive_names_table :inactive_names
  @inactive_oracles_table :inactive_oracles
  @opts [:named_table, :set, :public]

  @spec init() :: :ok
  def init do
    _tid1 = :ets.new(@active_names_table, @opts)
    _tid2 = :ets.new(@inactive_names_table, @opts)
    _tid3 = :ets.new(@active_oracles_table, @opts)
    _tid4 = :ets.new(@inactive_oracles_table, @opts)
    :ok
  end

  @spec put_active_name(String.t()) :: :ok
  def put_active_name(name) do
    put(@active_names_table, name)
    del(@inactive_names_table, name)
    :ok
  end

  @spec put_inactive_name(String.t()) :: :ok
  def put_inactive_name(name) do
    put(@inactive_names_table, name)
    del(@active_names_table, name)
    :ok
  end

  @spec count_active_names() :: non_neg_integer()
  def count_active_names, do: count(@active_names_table)

  @spec count_inactive_names() :: non_neg_integer()
  def count_inactive_names, do: count(@inactive_names_table)

  @spec put_active_oracle(pubkey()) :: :ok
  def put_active_oracle(oracle) do
    put(@active_oracles_table, oracle)
    del(@inactive_oracles_table, oracle)
    :ok
  end

  @spec put_inactive_oracle(pubkey()) :: :ok
  def put_inactive_oracle(oracle) do
    put(@inactive_oracles_table, oracle)
    del(@active_oracles_table, oracle)
    :ok
  end

  @spec count_active_oracles() :: non_neg_integer()
  def count_active_oracles, do: count(@active_oracles_table)

  @spec count_inactive_oracles() :: non_neg_integer()
  def count_inactive_oracles, do: count(@inactive_oracles_table)

  defp put(table, key), do: :ets.insert(table, {key})
  defp del(table, key), do: :ets.delete(table, key)
  defp count(table), do: :ets.info(table, :size)
end
