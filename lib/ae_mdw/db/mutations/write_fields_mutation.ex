defmodule AeMdw.Db.WriteFieldsMutation do
  @moduledoc """
  Stores the indexes for the Fields table.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Node
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.IdCounter
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.TxnMutation
  defstruct [:type, :tx, :block_index, :txi]

  @opaque t() :: %__MODULE__{
            type: Node.tx_type(),
            tx: Model.tx(),
            block_index: Blocks.block_index(),
            txi: Txs.txi()
          }

  @spec new(Node.tx_type(), Model.tx(), Blocks.block_index(), Txs.txi()) :: t()
  def new(type, tx, block_index, txi) do
    %__MODULE__{
      type: type,
      tx: tx,
      block_index: block_index,
      txi: txi
    }
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{type: tx_type, tx: tx, block_index: block_index, txi: txi}, txn) do
    tx_type
    |> Node.tx_ids()
    |> Enum.each(fn {field, pos} ->
      <<_::256>> = pk = resolve_pubkey(elem(tx, pos), tx_type, field, block_index)
      write_field(txn, tx_type, pos, pk, txi)
    end)
  end

  defp write_field(txn, tx_type, pos, pubkey, txi) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    Database.write(txn, Model.Field, m_field)
    IdCounter.incr_count(txn, {tx_type, pos, pubkey})
  end

  defp resolve_pubkey(id, :spend_tx, :recipient_id, block_index) do
    case :aeser_id.specialize(id) do
      {:name, name_hash} ->
        AeMdw.Db.Name.ptr_resolve!(block_index, name_hash, "account_pubkey")

      {_tag, pk} ->
        pk
    end
  end

  defp resolve_pubkey(id, _type, _field, _block_index) do
    {_tag, pk} = :aeser_id.specialize(id)
    pk
  end
end
