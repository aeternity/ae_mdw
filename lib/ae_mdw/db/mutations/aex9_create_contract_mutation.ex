defmodule AeMdw.Db.Aex9CreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 token info.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Txs

  @derive AeMdw.Db.TxnMutation
  defstruct [
    :contract_pk,
    :aex9_meta_info,
    :caller_pk,
    :create_txi
  ]

  @typep pubkey() :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            contract_pk: pubkey(),
            aex9_meta_info: Contract.aex9_meta_info(),
            caller_pk: pubkey(),
            create_txi: Txs.txi()
          }

  @spec new(
          pubkey(),
          Contract.aex9_meta_info(),
          pubkey(),
          Txs.txi()
        ) :: t()
  def new(contract_pk, aex9_meta_info, caller_pk, create_txi) do
    %__MODULE__{
      contract_pk: contract_pk,
      aex9_meta_info: aex9_meta_info,
      caller_pk: caller_pk,
      create_txi: create_txi
    }
  end

  @spec execute(t(), AeMdw.Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          aex9_meta_info: aex9_meta_info,
          caller_pk: caller_pk,
          create_txi: create_txi
        },
        txn
      ) do
    DBContract.aex9_creation_write(txn, aex9_meta_info, contract_pk, caller_pk, create_txi)
    :ok
  end
end
