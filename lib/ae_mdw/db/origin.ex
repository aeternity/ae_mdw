defmodule AeMdw.Db.Origin do
  alias AeMdw.Contract
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @typep contract_locator() :: {:contract, Txs.txi()} | {:contract_call, Txs.txi()}

  ##########

  @spec block_index({:contract, binary()}) :: map()
  def block_index({:contract, id}),
    do: map_some(tx_index({:contract, id}), &Model.tx(read_tx!(&1), :block_index))

  @spec tx_index({:contract, binary()}) :: nil | non_neg_integer()
  def tx_index({:contract, id}) do
    pk = Validate.id!(id)

    case prev(Model.Origin, {:contract_create_tx, pk, <<>>}) do
      :"$end_of_table" ->
        nil

      {:contract_create_tx, ^pk, txi} ->
        txi

      {:contract_create_tx, _pk, _txi} ->
        # contract_create_tx does not exist because contract was created on a contract call.
        nil
    end
  end

  @spec pubkey(contract_locator()) :: Contract.id() | nil
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
end
