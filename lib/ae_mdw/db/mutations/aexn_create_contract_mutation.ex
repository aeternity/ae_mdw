defmodule AeMdw.Db.AexnCreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 or AEX141 token info.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [
    :aexn_type,
    :contract_pk,
    :aexn_meta_info,
    :block_index,
    :create_txi
  ]

  @typep aexn_type :: AeMdw.Db.Model.aexn_type()
  @typep aexn_meta_info :: AeMdw.Db.Model.aexn_meta_info()
  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            aexn_type: aexn_type(),
            contract_pk: pubkey(),
            aexn_meta_info: aexn_meta_info(),
            block_index: Blocks.block_index(),
            create_txi: Txs.txi()
          }

  @spec new(
          aexn_type(),
          pubkey(),
          aexn_meta_info(),
          Blocks.block_index(),
          Txs.txi()
        ) :: t()
  def new(aexn_type, contract_pk, aexn_meta_info, block_index, create_txi) do
    %__MODULE__{
      aexn_type: aexn_type,
      contract_pk: contract_pk,
      aexn_meta_info: aexn_meta_info,
      block_index: block_index,
      create_txi: create_txi
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          aexn_type: aexn_type,
          contract_pk: contract_pk,
          aexn_meta_info: aexn_meta_info,
          block_index: {kbi, mbi},
          create_txi: create_txi
        },
        state
      ) do
    state =
      DBContract.aexn_creation_write(state, aexn_type, aexn_meta_info, contract_pk, create_txi)

    if aexn_type == :aex9 do
      AsyncTasks.Producer.enqueue(:derive_aex9_presence, [contract_pk, kbi, mbi, create_txi])
    end

    state
  end
end
