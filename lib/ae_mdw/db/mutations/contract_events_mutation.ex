defmodule AeMdw.Db.ContractEventsMutation do
  @moduledoc """
  Stores the internal contract calls by using the contract events.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Sync
  alias AeMdw.Txs

  defstruct [:ct_pk, :events, :txi]

  @typep event() :: Contract.event()
  @opaque t() :: %__MODULE__{
            ct_pk: DBContract.pubkey(),
            events: [event()],
            txi: Txs.txi()
          }

  @spec new(DBContract.pubkey(), [event()], Txs.txi()) :: t()
  def new(ct_pk, events, txi) do
    %__MODULE__{ct_pk: ct_pk, events: events, txi: txi}
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{ct_pk: ct_pk, events: events, txi: txi}) do
    ct_txi = Sync.Contract.get_txi(ct_pk)
    Sync.Contract.events(events, txi, ct_txi)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.ContractEventsMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
