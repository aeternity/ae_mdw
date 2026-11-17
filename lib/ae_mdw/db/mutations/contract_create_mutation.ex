defmodule AeMdw.Db.ContractCreateMutation do
  @moduledoc """
  Processes contract_create_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Mutation
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

  # nil for any other mutation
  @spec call_rec(Mutation.t()) :: Contract.call() | nil
  def call_rec(%__MODULE__{call_rec: call_rec}), do: call_rec
  def call_rec(_mutation), do: nil

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
      DBContract.logs_write(state, txi, txi, call_rec, true)
    else
      state
    end
  end
end
