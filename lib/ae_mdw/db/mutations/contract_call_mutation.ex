defmodule AeMdw.Db.ContractCallMutation do
  @moduledoc """
  Processes contract_call_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Txs

  defstruct [:create_txi, :txi, :fun_arg_res, :call_rec]

  @typep txi_option() :: Txs.txi() | -1

  @opaque t() :: %__MODULE__{
            create_txi: txi_option(),
            txi: Txs.txi(),
            fun_arg_res: Contract.fun_arg_res(),
            call_rec: Contract.call()
          }

  @spec new(txi_option(), Txs.txi(), Contract.fun_arg_res(), Contract.call()) :: t()
  def new(create_txi, txi, fun_arg_res, call_rec) do
    %__MODULE__{
      create_txi: create_txi,
      txi: txi,
      fun_arg_res: fun_arg_res,
      call_rec: call_rec
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        create_txi: create_txi,
        txi: txi,
        fun_arg_res: fun_arg_res,
        call_rec: call_rec
      }) do
    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.ContractCallMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
