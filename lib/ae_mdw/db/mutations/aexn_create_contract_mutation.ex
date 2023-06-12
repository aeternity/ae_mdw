defmodule AeMdw.Db.AexnCreateContractMutation do
  @moduledoc """
  Maps a contract to its AEX9 or AEX141 token info.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Blocks
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats
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
    |> maybe_increment_contract_count(aexn_type, aexn_meta_info)
    |> write_balances(aexn_type, contract_pk, block_index, create_txi)
    |> Contract.aexn_creation_write(
      aexn_type,
      aexn_meta_info,
      contract_pk,
      create_txi,
      extensions
    )
  end

  defp maybe_increment_contract_count(state, aexn_type, aexn_meta_info) do
    if AexnContracts.valid_meta_info?(aexn_meta_info) do
      Stats.increment_contract_count(state, aexn_type)
    else
      state
    end
  end

  defp write_balances(state, :aex9, contract_pk, block_index, create_txi) do
    task = Task.async(Aex9Balances, :get_balances, [contract_pk, block_index])

    case Task.yield(task, @dry_run_timeout) || Task.shutdown(task) do
      {:ok, {:ok, balances, _no_purge}} ->
        Contract.aex9_init_event_balances(state, contract_pk, balances, create_txi)

      {:ok, _dry_run_error} ->
        state

      nil ->
        State.enqueue(state, :update_aex9_state, [contract_pk], [block_index, create_txi])
    end
  end

  defp write_balances(state, _aexn, _contract_pk, _block_index, _txi), do: state
end
