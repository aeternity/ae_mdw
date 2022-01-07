defmodule AeMdw.Db.ContractCallMutation do
  @moduledoc """
  Processes contract_call_tx.
  """

  alias AeMdw.Node
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs

  defstruct [:contract_pk, :caller_pk, :create_txi, :txi, :fun_arg_res, :call_rec]

  @typep txi_option() :: Txs.txi() | -1

  @opaque t() :: %__MODULE__{
            contract_pk: Node.pubkey(),
            caller_pk: Node.pubkey(),
            create_txi: txi_option(),
            txi: Txs.txi(),
            fun_arg_res: Contract.fun_arg_res_or_error(),
            call_rec: Contract.call()
          }

  @spec new(
          Node.pubkey(),
          Node.pubkey(),
          txi_option(),
          Txs.txi(),
          Contract.fun_arg_res_or_error(),
          Contract.call()
        ) :: t()
  def new(contract_pk, caller_pk, create_txi, txi, fun_arg_res, call_rec) do
    %__MODULE__{
      contract_pk: contract_pk,
      caller_pk: caller_pk,
      create_txi: create_txi,
      txi: txi,
      fun_arg_res: fun_arg_res,
      call_rec: call_rec
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        contract_pk: contract_pk,
        caller_pk: caller_pk,
        create_txi: create_txi,
        txi: txi,
        fun_arg_res: fun_arg_res,
        call_rec: call_rec
      }) do
    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)

    if Contract.is_aex9?(contract_pk) and Contract.is_successful_call?(fun_arg_res) and
         not Contract.is_non_stateful_aex9_function?(fun_arg_res.function) do
      update_aex9_presence(
        contract_pk,
        caller_pk,
        txi,
        fun_arg_res.function,
        fun_arg_res.arguments
      )
    end

    :ok
  end

  #
  # Private functions
  #
  defp update_aex9_presence(contract_pk, caller_pk, txi, method_name, method_args) do
    account_pk = Contract.get_aex9_destination_address(method_name, method_args)

    if account_pk do
      DBContract.aex9_write_presence(contract_pk, txi, account_pk)
    else
      if method_name in ["burn", "swap"] do
        DBContract.aex9_delete_presence(contract_pk, caller_pk)
      else
        AsyncTasks.Producer.enqueue(:update_aex9_presence, [contract_pk])
      end
    end
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.ContractCallMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
