defmodule AeMdw.Db.ContractCreateMutation do
  @moduledoc """
  Processes contract_create_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.State
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:txi, :call_rec]

  @opaque t() :: %__MODULE__{
            txi: Txs.txi(),
            call_rec: Contract.call() | nil
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

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          txi: txi,
          call_rec: call_rec
        },
        state
      ) do
    contract_pk = :aect_call.contract_pubkey(call_rec)

    state =
      state
      |> State.inc_stat(:contracts_created)
      |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)

    if call_rec != nil do
      DBContract.logs_write(state, txi, txi, call_rec)
    else
      state
    end
  end
end
