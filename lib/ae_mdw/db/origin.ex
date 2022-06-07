defmodule AeMdw.Db.Origin do
  @moduledoc false

  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  import AeMdw.Util

  @contract_creation_types ~w(contract_create_tx contract_call_tx ga_attach_tx)a

  @typep contract_locator() :: {:contract, Txs.txi()} | {:contract_call, Txs.txi()}
  @typep creation_txi_locator() :: {:contract, Db.pubkey()}

  ##########

  @spec block_index(State.t(), {:contract, binary()}) :: map()
  def block_index(state, {:contract, id}),
    do:
      map_some(
        tx_index(state, {:contract, id}),
        &Model.tx(DbUtil.read_tx!(state, &1), :block_index)
      )

  @doc """
  Tries to find the transaction that created a contract by finding it from 3
  sources:

  * From the Field table, where the key would be
    `{:contract_create_tx, nil, pk, txi}`.
  * From the Field table, where the key would be
    `{:contract_call_tx, nil, pk, txi}` (contracts created via `Chain.clone` or
    `Chain.create`).
  * From the Field table, where the key would be
    `{:ga_attach_tx, nil, pk, txi}` (GA contracts created via GaAttachTx).
  * From the list of whitelisted contracts that weren't created via contract
    create transactions or via contract calls. These contracts are hard-coded
    and created through core hard-forks. These contracts will have a negative
    txi where the number is the index of the preloaded contracts.
  """
  @spec tx_index(State.t(), creation_txi_locator()) :: {:ok, Txs.txi() | -1} | :not_found
  def tx_index(state, {:contract, pk}) do
    with :error <- field_txi(state, :contract_create_tx, nil, pk),
         :error <- field_txi(state, :contract_call_tx, nil, pk),
         :error <- field_txi(state, :ga_attach_tx, nil, pk) do
      case Enum.find_index(preset_contracts(), &match?(^pk, &1)) do
        nil -> :not_found
        index -> {:ok, -index - 1}
      end
    end
  end

  @spec tx_index!(State.t(), creation_txi_locator()) :: Txs.txi()
  def tx_index!(state, {:contract, pk} = creation_txi_locator) do
    case State.cache_get(state, :ct_create_sync_cache, pk) do
      {:ok, txi} ->
        txi

      :not_found ->
        case tx_index(state, creation_txi_locator) do
          {:ok, txi} -> txi
          :not_found -> raise "Origin #{inspect(creation_txi_locator)} not found"
        end
    end
  end

  @spec pubkey!(State.t(), contract_locator()) :: Contract.id()
  def pubkey!(state, contract_locator) do
    case pubkey(state, contract_locator) do
      nil -> raise "Invalid contract #{inspect(contract_locator)}"
      pubkey -> pubkey
    end
  end

  @spec pubkey(State.t(), contract_locator()) :: Contract.id() | nil
  def pubkey(_state, {:contract, txi}) when txi < 0 do
    preset_contracts()
    |> Enum.at(abs(txi) - 1)
  end

  def pubkey(state, {:contract, txi}) do
    case State.next(state, Model.RevOrigin, {txi, -1, <<>>}) do
      {:ok, {^txi, type, pubkey}} when type in @contract_creation_types -> pubkey
      _key_mismatch -> nil
    end
  end

  def pubkey(state, {:contract_call, call_txi}) do
    Model.tx(id: tx_hash) = DbUtil.read_tx!(state, call_txi)

    {_block_hash, :contract_call_tx, _siged_tx, tx_rec} = Db.get_tx_data(tx_hash)

    {:contract, contract_id} =
      tx_rec
      |> :aect_call_tx.contract_id()
      |> :aeser_id.specialize()

    contract_id
  end

  @spec count_contracts(State.t()) :: non_neg_integer()
  def count_contracts(state) do
    count_by_tx_type(state, :contract_create_tx) + count_by_tx_type(state, :contract_call_tx)
  end

  #
  # Private functions
  #
  defp field_txi(state, tx_type, pos, pk) do
    case State.next(state, Model.Field, {tx_type, pos, pk, -1}) do
      {:ok, {^tx_type, ^pos, ^pk, txi}} -> {:ok, txi}
      _key_mismatch -> :error
    end
  end

  defp count_by_tx_type(state, tx_type) do
    state
    |> Collection.stream(Model.Origin, {tx_type, Util.min_bin(), nil})
    |> Stream.take_while(&match?({^tx_type, _pubkey, _txi}, &1))
    |> Enum.count()
  end

  defp preset_contracts do
    :aec_fork_block_settings.lima_contracts()
    |> Enum.map(fn %{pubkey: pubkey} -> pubkey end)
  end
end
