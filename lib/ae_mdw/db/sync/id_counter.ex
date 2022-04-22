defmodule AeMdw.Db.Sync.IdCounter do
  @moduledoc """
  Counts the ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec incr_count(State.t(), Model.id_count_key()) :: State.t()
  def incr_count(state, {_, _, _} = field_key) do
    update_count(state, field_key, 1)
  end

  @spec update_count(State.t(), Model.id_count_key(), integer()) :: State.t()
  def update_count(state, {_, _, _} = field_key, delta) do
    case State.get(state, AeMdw.Db.Model.IdCount, field_key) do
      :not_found ->
        model = Model.id_count(index: field_key, count: 0)
        write_count(state, model, 1)

      {:ok, model} ->
        write_count(state, model, delta)
    end
  end

  #
  # Private
  #
  @spec write_count(State.t(), Model.id_count(), integer()) :: State.t()
  defp write_count(state, Model.id_count(count: total) = model, delta) do
    model = Model.id_count(model, count: total + delta)
    State.put(state, AeMdw.Db.Model.IdCount, model)
  end
end
