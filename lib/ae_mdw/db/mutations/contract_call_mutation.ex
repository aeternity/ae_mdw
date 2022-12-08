defmodule AeMdw.Db.ContractCallMutation do
  @moduledoc """
  Processes contract_call_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [
    :contract_pk,
    :txi,
    :fun_arg_res,
    :call_rec
  ]

  @typep pubkey() :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            contract_pk: pubkey(),
            txi: Txs.txi(),
            fun_arg_res: Contract.fun_arg_res_or_error(),
            call_rec: Contract.call()
          }

  @spec new(
          pubkey(),
          Txs.txi(),
          Contract.fun_arg_res_or_error(),
          Contract.call()
        ) :: t()
  def new(contract_pk, txi, fun_arg_res, call_rec) do
    %__MODULE__{
      contract_pk: contract_pk,
      txi: txi,
      fun_arg_res: fun_arg_res,
      call_rec: call_rec
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          txi: txi,
          fun_arg_res: fun_arg_res,
          call_rec: call_rec
        },
        state
      ) do
    create_txi =
      case State.cache_get(state, :ct_create_sync_cache, contract_pk) do
        {:ok, txi} -> txi
        :not_found -> Origin.tx_index!(state, {:contract, contract_pk})
      end

    state
    |> DBContract.call_write(create_txi, txi, fun_arg_res)
    |> DBContract.logs_write(create_txi, txi, call_rec)
  end
end
