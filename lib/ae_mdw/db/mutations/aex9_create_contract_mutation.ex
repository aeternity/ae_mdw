defmodule AeMdw.Db.Aex9CreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 token info.
  """

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [
    :contract_pk,
    :aex9_meta_info,
    :block_index,
    :create_txi
  ]

  @typep pubkey() :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            contract_pk: pubkey(),
            aex9_meta_info: Contract.aex9_meta_info(),
            block_index: Blocks.block_index(),
            create_txi: Txs.txi()
          }

  @spec new(
          pubkey(),
          Contract.aex9_meta_info(),
          Blocks.block_index(),
          Txs.txi()
        ) :: t()
  def new(contract_pk, aex9_meta_info, block_index, create_txi) do
    %__MODULE__{
      contract_pk: contract_pk,
      aex9_meta_info: aex9_meta_info,
      block_index: block_index,
      create_txi: create_txi
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          aex9_meta_info: aex9_meta_info,
          block_index: {kbi, mbi},
          create_txi: create_txi
        },
        state
      ) do
    state = DBContract.aex9_creation_write(state, aex9_meta_info, contract_pk, create_txi)

    AsyncTasks.Producer.enqueue(:derive_aex9_presence, [contract_pk, kbi, mbi, create_txi])
    AsyncTasks.Producer.commit_enqueued()
    state
  end
end
