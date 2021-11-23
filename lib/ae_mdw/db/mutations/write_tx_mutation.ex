defmodule AeMdw.Db.WriteTxMutation do
  @moduledoc """
  Indexes a transaction into the Tx, Type and Time tables.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Node
  alias AeMdw.Txs

  require Model

  defstruct [:tx, :type, :txi, :mb_time, :inner_tx?]

  @opaque t() :: %__MODULE__{
            tx: Model.tx(),
            type: Node.tx_type(),
            txi: Txs.txi(),
            mb_time: Blocks.time(),
            inner_tx?: boolean()
          }

  @spec new(Model.tx(), Node.tx_type(), Txs.txi(), Blocks.time(), boolean()) :: t()
  def new(tx, type, txi, mb_time, inner_tx?) do
    %__MODULE__{
      tx: tx,
      type: type,
      txi: txi,
      mb_time: mb_time,
      inner_tx?: inner_tx?
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{tx: tx, type: type, txi: txi, mb_time: mb_time, inner_tx?: inner_tx?}) do
    if not inner_tx? do
      :mnesia.write(Model.Tx, tx, :write)
    end

    :mnesia.write(Model.Type, Model.type(index: {type, txi}), :write)
    :mnesia.write(Model.Time, Model.time(index: {mb_time, txi}), :write)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.WriteTxMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
