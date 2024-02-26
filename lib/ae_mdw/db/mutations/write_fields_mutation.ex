defmodule AeMdw.Db.WriteFieldsMutation do
  @moduledoc """
  Stores the indexes for the Fields table.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Fields
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Sync.IdCounter
  alias AeMdw.Txs

  require Model

  @typep wrap_tx :: :ga_meta_tx | :paying_for_tx | nil

  @derive AeMdw.Db.Mutation
  defstruct [:type, :tx, :block_index, :txi, :wrap_tx]

  @opaque t() :: %__MODULE__{
            type: Node.tx_type(),
            tx: Node.tx(),
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            wrap_tx: wrap_tx()
          }

  @spec new(Node.tx_type(), Node.tx(), Blocks.block_index(), Txs.txi(), wrap_tx()) :: t()
  def new(type, tx, block_index, txi, wrap_tx \\ nil) do
    %__MODULE__{
      type: type,
      tx: tx,
      block_index: block_index,
      txi: txi,
      wrap_tx: wrap_tx
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{type: tx_type, tx: tx, block_index: block_index, txi: txi, wrap_tx: wrap_tx},
        state
      ) do
    tx_type
    |> Node.tx_ids()
    |> Enum.map(fn {field, pos} ->
      pk = resolve_pubkey(state, elem(tx, pos), tx_type, field, block_index)
      field_pos = Fields.field_pos_mask(wrap_tx, pos)
      {tx_type, pos} = if wrap_tx, do: {wrap_tx, field_pos}, else: {tx_type, pos}

      {tx_type, pos, pk}
    end)
    |> Enum.group_by(fn {_tx_type, _pos, pk} -> pk end)
    |> Enum.flat_map(fn {pk, field_indexes} ->
      is_repeated? = length(field_indexes) > 1

      Enum.map(field_indexes, fn {tx_type, pos, ^pk} ->
        {tx_type, pos, pk, is_repeated?}
      end)
    end)
    |> Enum.reduce(state, fn {tx_type, pos, pk, is_repeated?}, state ->
      m_field = Model.field(index: {tx_type, pos, pk, txi})

      state
      |> State.put(Model.Field, m_field)
      |> IdCounter.incr_count(tx_type, pos, pk, is_repeated?)
    end)
  end

  defp resolve_pubkey(state, id, :spend_tx, :recipient_id, block_index) do
    with {:name, name_hash} <- :aeser_id.specialize(id),
         {:ok, account_pk} <- Name.ptr_resolve(state, block_index, name_hash) do
      account_pk
    else
      {:error, :name_revoked} ->
        Log.warn("Revoked name used on spend! id: #{id}, block_index: #{block_index}")
        Name.last_update_pointee_pubkey(state, id)

      {_pk_type, pk} ->
        pk
    end
  end

  defp resolve_pubkey(_state, id, _type, _field, _block_index) do
    {_tag, pk} = :aeser_id.specialize(id)
    pk
  end
end
