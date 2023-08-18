defmodule AeMdw.Db.Sync.IdCounter do
  @moduledoc """
  Counts the ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Db.State

  require Model

  @typep pubkey() :: Db.pubkey()

  @spec incr_count(State.t(), Node.tx_type(), non_neg_integer(), pubkey(), boolean()) :: State.t()
  def incr_count(state, tx_type, pos, pk, is_repeated?) do
    state = incr_id_count(state, Model.IdCount, {tx_type, pos, pk})

    if is_repeated? do
      incr_id_count(state, Model.DupIdCount, {tx_type, pos, pk})
    else
      state
    end
  end

  defp incr_id_count(state, table, field_key) do
    State.update(
      state,
      table,
      field_key,
      fn
        Model.id_count(count: count) = id_count -> Model.id_count(id_count, count: count + 1)
      end,
      Model.id_count(index: field_key, count: 0)
    )
  end
end
