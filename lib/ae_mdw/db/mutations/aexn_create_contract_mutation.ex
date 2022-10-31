defmodule AeMdw.Db.AexnCreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 or AEX141 token info.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.Aex9Balances
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

  @dry_run_timeout 250

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
          block_index: block_index,
          create_txi: create_txi,
          extensions: extensions
        },
        state
      ) do
    state
    |> write_balances(aexn_type, contract_pk, block_index, create_txi)
    |> Contract.aexn_creation_write(
      aexn_type,
      aexn_meta_info,
      contract_pk,
      create_txi,
      extensions
    )
  end

  defp write_balances(state, :aex9, contract_pk, block_index, create_txi) do
    Aex9Balances
    |> Task.async(:get_balances, [contract_pk, block_index])
    |> Task.yield(@dry_run_timeout)
    |> case do
      {:ok, {:ok, balances, _no_purge}} ->
        state
        |> Contract.aex9_write_balances(contract_pk, balances, block_index, create_txi)
        |> Contract.aex9_init_event_balances(contract_pk, balances, create_txi)

      _timeout_or_error ->
        state
    end
  end

  defp write_balances(state, _aexn, _contract_pk, _block_index, _txi), do: state
end
