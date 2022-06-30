defmodule AeMdw.Db.AexnCreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 or AEX141 token info.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [
    :aexn_type,
    :contract_pk,
    :aexn_meta_info,
    :block_index,
    :create_txi,
    :extensions
  ]

  @typep aexn_type :: AeMdw.Db.Model.aexn_type()
  @typep aexn_meta_info :: AeMdw.Db.Model.aexn_meta_info()
  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @opaque t() :: %__MODULE__{
            aexn_type: aexn_type(),
            contract_pk: pubkey(),
            aexn_meta_info: aexn_meta_info(),
            block_index: Blocks.block_index(),
            create_txi: Txs.txi(),
            extensions: Model.aexn_extensions()
          }

  @spec new(
          aexn_type(),
          pubkey(),
          aexn_meta_info(),
          Blocks.block_index(),
          Txs.txi(),
          Model.aexn_extensions()
        ) :: t()
  def new(aexn_type, contract_pk, aexn_meta_info, block_index, create_txi, extensions) do
    %__MODULE__{
      aexn_type: aexn_type,
      contract_pk: contract_pk,
      aexn_meta_info: aexn_meta_info,
      block_index: block_index,
      create_txi: create_txi,
      extensions: extensions
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          aexn_type: aexn_type,
          contract_pk: contract_pk,
          aexn_meta_info: aexn_meta_info,
          block_index: {kbi, mbi},
          create_txi: create_txi,
          extensions: extensions
        },
        state
      ) do
    state =
      DBContract.aexn_creation_write(
        state,
        aexn_type,
        aexn_meta_info,
        contract_pk,
        create_txi,
        extensions
      )

    if aexn_type == :aex9 do
      State.enqueue(state, :derive_aex9_presence, [contract_pk, kbi, mbi, create_txi])
    else
      state
    end
  end
end
