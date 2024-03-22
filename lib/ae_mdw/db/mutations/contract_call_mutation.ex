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
            call_rec: Contract.call() | nil
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
          contract_pk: contract_or_name_pk,
          txi: txi,
          fun_arg_res: fun_arg_res,
          call_rec: call_rec
        },
        state
      ) do
    contract_pk = Contract.maybe_resolve_contract_pk(contract_or_name_pk)
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    state = DBContract.call_write(state, create_txi, txi, fun_arg_res)

    if call_rec != nil do
      DBContract.logs_write(state, create_txi, txi, call_rec)
    else
      state
    end
  end
end
