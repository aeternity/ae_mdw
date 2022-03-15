defmodule AeMdw.Db.Sync.IdCounter do
  @moduledoc """
  Counts the ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model

  require Model

  @spec incr_count(Database.transaction(), Model.id_count_key()) :: :ok
  def incr_count(txn, {_, _, _} = field_key) do
    update_count(txn, field_key, 1)
  end

  @spec update_count(Database.transaction(), Model.id_count_key(), integer()) :: :ok
  def update_count(txn, {_, _, _} = field_key, delta) do
    case Database.read(AeMdw.Db.Model.IdCount, field_key, :write) do
      [] ->
        model = Model.id_count(index: field_key, count: 0)
        write_count(txn, model, 1)

      [model] ->
        write_count(txn, model, delta)
    end

    :ok
  end

  #
  # Private
  #
  @spec write_count(Database.transaction(), Model.id_count(), integer()) :: :ok
  defp write_count(txn, Model.id_count(count: total) = model, delta) do
    model = Model.id_count(model, count: total + delta)
    Database.write(txn, AeMdw.Db.Model.IdCount, model)
  end
end
