defmodule AeMdw.Db.ContractCallMutation do
  @moduledoc """
  Processes contract_call_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs
  alias AeMdw.Validate

  @derive AeMdw.Db.Mutation
  defstruct [
    :contract_pk,
    :caller_pk,
    :txi,
    :fun_arg_res,
    :call_rec
  ]

  @typep pubkey() :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            contract_pk: pubkey(),
            caller_pk: pubkey(),
            txi: Txs.txi(),
            fun_arg_res: Contract.fun_arg_res_or_error(),
            call_rec: Contract.call()
          }

  @spec new(
          pubkey(),
          pubkey(),
          Txs.txi(),
          Contract.fun_arg_res_or_error(),
          Contract.call()
        ) :: t()
  def new(contract_pk, caller_pk, txi, fun_arg_res, call_rec) do
    %__MODULE__{
      contract_pk: contract_pk,
      caller_pk: caller_pk,
      txi: txi,
      fun_arg_res: fun_arg_res,
      call_rec: call_rec
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          caller_pk: caller_pk,
          txi: txi,
          fun_arg_res: fun_arg_res,
          call_rec: call_rec
        },
        state
      ) do
    create_txi =
      case State.cache_get(state, :ct_create_sync_cache, contract_pk) do
        {:ok, txi} -> txi
        :not_found -> Origin.tx_index!({:contract, contract_pk})
      end

    state2 =
      state
      |> DBContract.call_write(create_txi, txi, fun_arg_res)
      |> DBContract.logs_write(create_txi, txi, call_rec)

    # update balance on any call
    AsyncTasks.Producer.enqueue(:update_aex9_state, [contract_pk])

    with true <- Contract.is_aex9?(contract_pk),
         {:ok, method_name, method_args} <- Contract.extract_successful_function(fun_arg_res),
         false <- Contract.is_non_stateful_aex9_function?(method_name) do
      # writes already known presence
      update_aex9_presence(
        state2,
        contract_pk,
        caller_pk,
        txi,
        method_name,
        method_args
      )
    else
      _invalid -> state2
    end
  end

  #
  # Private functions
  #
  defp update_aex9_presence(state, contract_pk, caller_pk, txi, method_name, method_args) do
    write_aex9_presence(state, method_name, method_args, contract_pk, caller_pk, txi)
  end

  defp write_aex9_presence(
         state,
         "burn",
         [%{type: :int, value: _value}],
         contract_pk,
         caller_pk,
         txi
       ) do
    DBContract.aex9_write_presence(state, contract_pk, txi, caller_pk)
  end

  defp write_aex9_presence(state, "swap", [], contract_pk, caller_pk, txi) do
    DBContract.aex9_write_presence(state, contract_pk, txi, caller_pk)
  end

  defp write_aex9_presence(
         state,
         "mint",
         [
           %{type: :address, value: to_account_id},
           %{type: :int, value: _value}
         ],
         contract_pk,
         _caller_pk,
         txi
       ) do
    to_pk = Validate.id!(to_account_id)

    DBContract.aex9_write_presence(state, contract_pk, txi, to_pk)
  end

  defp write_aex9_presence(state, method_name, method_args, contract_pk, caller_pk, txi) do
    case Contract.get_aex9_transfer(caller_pk, method_name, method_args) do
      {from_pk, to_pk, _value} ->
        state
        |> DBContract.aex9_write_presence(contract_pk, txi, from_pk)
        |> DBContract.aex9_write_presence(contract_pk, txi, to_pk)

      nil ->
        state
    end
  end
end
