defmodule AeMdw.Db.ContractCallMutation do
  @moduledoc """
  Processes contract_call_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [
    :contract_pk,
    :caller_pk,
    :create_txi,
    :txi,
    :fun_arg_res,
    :call_rec,
    :aex9_meta_info
  ]

  @typep pubkey() :: AeMdw.Node.Db.pubkey()
  @typep txi_option() :: Txs.txi() | -1

  @opaque t() :: %__MODULE__{
            contract_pk: pubkey(),
            caller_pk: pubkey(),
            create_txi: txi_option(),
            txi: Txs.txi(),
            fun_arg_res: Contract.fun_arg_res_or_error(),
            aex9_meta_info: Contract.aex9_meta_info() | nil,
            call_rec: Contract.call()
          }

  @spec new(
          pubkey(),
          pubkey(),
          txi_option(),
          Txs.txi(),
          Contract.fun_arg_res_or_error(),
          Contract.aex9_meta_info() | nil,
          Contract.call()
        ) :: t()
  def new(contract_pk, caller_pk, create_txi, txi, fun_arg_res, aex9_meta_info, call_rec) do
    %__MODULE__{
      contract_pk: contract_pk,
      caller_pk: caller_pk,
      create_txi: create_txi,
      txi: txi,
      fun_arg_res: fun_arg_res,
      aex9_meta_info: aex9_meta_info,
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
        aex9_meta_info: aex9_meta_info,
        call_rec: call_rec
      }) do
    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)

    with true <- Contract.is_aex9?(contract_pk),
         {:ok, method_name, method_args} <-
           Contract.extract_non_stateful_aex9_function(fun_arg_res) do
      update_aex9_presence(
        contract_pk,
        caller_pk,
        txi,
        method_name,
        method_args
      )
    end

    if aex9_meta_info do
      DBContract.aex9_creation_write(aex9_meta_info, contract_pk, caller_pk, txi)
    end

    :ok
  end

  #
  # Private functions
  #
  defp update_aex9_presence(contract_pk, caller_pk, txi, method_name, method_args) do
    account_pk =
      if method_name in ["burn", "swap"] do
        caller_pk
      else
        Contract.get_aex9_destination_address(method_name, method_args)
      end

    if account_pk do
      DBContract.aex9_write_presence(contract_pk, txi, account_pk)
    else
      AsyncTasks.Producer.enqueue(:update_aex9_presence, [contract_pk])
    end
  end
end
