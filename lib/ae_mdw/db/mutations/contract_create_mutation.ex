defmodule AeMdw.Db.ContractCreateMutation do
  @moduledoc """
  Processes contract_create_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:txi, :call_rec]

  @opaque t() :: %__MODULE__{
            txi: Txs.txi(),
            call_rec: Contract.call()
          }

  @spec new(
          Txs.txi(),
          Contract.call()
        ) :: t()
  def new(txi, call_rec) do
    %__MODULE__{
      txi: txi,
      call_rec: call_rec
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        txi: txi,
        call_rec: call_rec
      }) do
    AeMdw.Ets.inc(:stat_sync_cache, :contracts_created)
    DBContract.logs_write(txi, txi, call_rec)
  end
end
