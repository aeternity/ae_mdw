defmodule AeMdw.Db.Origin do
  @moduledoc false

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @typep contract_locator() :: {:contract, Txs.txi()} | {:contract_call, Txs.txi()}
  @typep creation_txi_locator() :: {:contract, Db.pubkey()}

  ##########

  @spec block_index({:contract, binary()}) :: map()
  def block_index({:contract, id}),
    do: map_some(tx_index({:contract, id}), &Model.tx(read_tx!(&1), :block_index))

  @doc """
  Tries to find the transaction that created a contract by finding it from 3
  sources:

  * From the Field table, where the key would be
    `{:contract_create_tx, nil, pk, txi}`.
  * From the Field table, where the key would be
    `{:contract_call_tx, nil, pk, txi}` (contracts created via `Chain.clone` or
    `Chain.create`.
  * From the list of whitelisted contracts that weren't created via contract
    create transactions or via contract calls. These contracts are hard-coded
    and created through core hard-forks. These contracts will have a negative
    txi where the number is the index of the preloaded contracts.
  """
  @spec tx_index(creation_txi_locator()) :: {:ok, Txs.txi() | -1} | :not_found
  def tx_index({:contract, pk}) do
    with :error <- field_txi(:contract_create_tx, nil, pk),
         :error <- field_txi(:contract_call_tx, nil, pk) do
      case Enum.find_index(preset_contracts(), &match?(^pk, &1)) do
        nil -> :not_found
        index -> {:ok, -index - 1}
      end
    end
  end

  @spec tx_index!(creation_txi_locator()) :: Txs.txi()
  def tx_index!(creation_txi_locator) do
    case tx_index(creation_txi_locator) do
      {:ok, txi} -> txi
      :not_found -> raise "Origin #{inspect(creation_txi_locator)} not found"
    end
  end

  @spec pubkey!(contract_locator()) :: Contract.id()
  def pubkey!(contract_locator) do
    case pubkey(contract_locator) do
      nil -> raise "Invalid contract #{inspect(contract_locator)}"
      pubkey -> pubkey
    end
  end

  @spec pubkey(contract_locator()) :: Contract.id() | nil
  def pubkey({:contract, txi}) when txi < 0 do
    preset_contracts()
    |> Enum.at(abs(txi) - 1)
  end

  def pubkey({:contract, txi}) do
    case next(Model.RevOrigin, {txi, :contract_create_tx, <<>>}) do
      :"$end_of_table" -> nil
      {^txi, :contract_create_tx, pubkey} -> pubkey
      {_txi, _tx_type, _pubkey} -> nil
    end
  end

  def pubkey({:contract_call, call_txi}) do
    Model.tx(id: tx_hash) = read_tx!(call_txi)

    {_block_hash, :contract_call_tx, _siged_tx, tx_rec} = Db.get_tx_data(tx_hash)

    {:contract, contract_id} =
      tx_rec
      |> :aect_call_tx.contract_id()
      |> :aeser_id.specialize()

    contract_id
  end

  @spec count_contracts() :: non_neg_integer()
  def count_contracts do
    ct_list1 = do_list_by_tx_type([], {:contract_create_tx, <<>>, -1})
    ct_list2 = do_list_by_tx_type([], {:contract_call_tx, <<>>, -1})

    length(ct_list1) + length(ct_list2)
  end

  #
  # Private functions
  #
  defp field_txi(tx_type, pos, pk) do
    case next(Model.Field, {tx_type, pos, pk, -1}) do
      :"$end_of_table" -> :error
      {^tx_type, ^pos, ^pk, txi} -> {:ok, txi}
      {_tx_type, _pos, _pk, _txi} -> :error
    end
  end

  defp do_list_by_tx_type(origin_pks, {type, _pk, _txi} = key) do
    case next(Model.Origin, key) do
      {^type, pubkey, _txi} = next_key -> do_list_by_tx_type([pubkey | origin_pks], next_key)
      _not_the_type -> origin_pks
    end
  end

  defp preset_contracts do
    :aec_fork_block_settings.lima_contracts()
    |> Enum.map(fn %{pubkey: pubkey} -> pubkey end)
  end
end
