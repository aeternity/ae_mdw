defmodule AeMdwWeb.EtsManager do
  @moduledoc """
  Top level ets manager
  """
  alias AeMdwWeb.ContinuationData

  @table_name Application.get_env(:ae_mdw, AeMdwWeb.GCWorker)[:table_name]

  @spec is_member?(tuple()) :: boolean()
  def is_member?(key), do: :ets.member(@table_name, key)

  @spec get(tuple()) :: ContinuationData.t() | List.t()
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, state}] ->
        state

      data ->
        data
    end
  end

  @spec put(tuple(), List.t(), StreamSplit.t(), integer(), integer()) :: boolean()
  def put(key, endpoint, continuation, page, limit) do
    data = ContinuationData.create(endpoint, continuation, page, limit)
    :ets.insert(@table_name, {key, data})
  end

  @spec get_all_table() :: List.t()
  def get_all_table(), do: :ets.foldr(fn elem, acc -> [elem | acc] end, [], @table_name)

  @spec delete(tuple()) :: boolean()
  def delete(key), do: :ets.delete(@table_name, key)

  @spec delete_old_records(integer()) :: List.t()
  def delete_old_records(time) do
    :ets.foldr(
      fn {k, v}, acc ->
        if v.timestamp + time < :os.system_time(:millisecond) do
          delete(k)
        end
      end,
      [],
      @table_name
    )
  end
end
