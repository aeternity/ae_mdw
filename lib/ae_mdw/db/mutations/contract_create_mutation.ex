defmodule AeMdw.Db.ContractCreateMutation do
  @moduledoc """
  Processes contract_create_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.State
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:block_index, :txi, :call_rec]

  @opaque t() :: %__MODULE__{
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            call_rec: Contract.call()
          }

  @spec new(
          Blocks.block_index(),
          Txs.txi(),
          Contract.call()
        ) :: t()
  def new(block_index, txi, call_rec) do
    %__MODULE__{
      block_index: block_index,
      txi: txi,
      call_rec: call_rec
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          block_index: block_index,
          txi: txi,
          call_rec: call_rec
        },
        state
      ) do
    contract_pk = :aect_call.contract_pubkey(call_rec)

    state
    |> State.inc_stat(:contracts_created)
    |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
    |> DBContract.logs_write(block_index, txi, txi, call_rec)
  end
end
