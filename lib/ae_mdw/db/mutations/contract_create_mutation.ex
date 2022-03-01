defmodule AeMdw.Db.ContractCreateMutation do
  @moduledoc """
  Processes contract_create_tx.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :txi, :owner_pk, :aex9_meta_info, :call_rec]

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            txi: Txs.txi(),
            owner_pk: Db.pubkey(),
            aex9_meta_info: Contract.aex9_meta_info() | nil,
            call_rec: Contract.call()
          }

  @spec new(
          Db.pubkey(),
          Txs.txi(),
          Db.pubkey(),
          Contract.aex9_meta_info() | nil,
          Contract.call()
        ) :: t()
  def new(contract_pk, txi, owner_pk, aex9_meta_info, call_rec) do
    %__MODULE__{
      contract_pk: contract_pk,
      txi: txi,
      owner_pk: owner_pk,
      aex9_meta_info: aex9_meta_info,
      call_rec: call_rec
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        contract_pk: contract_pk,
        txi: txi,
        owner_pk: owner_pk,
        aex9_meta_info: aex9_meta_info,
        call_rec: call_rec
      }) do
    if aex9_meta_info do
      DBContract.aex9_creation_write(aex9_meta_info, contract_pk, owner_pk, txi)
    end

    DBContract.logs_write(txi, txi, call_rec)
  end
end
