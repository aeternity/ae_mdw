defmodule AeMdw.Db.Origin do
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

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

  @spec pubkey({:contract, term()}) :: term()
  def pubkey({:contract, txi}) do
    case next(Model.RevOrigin, {txi, :contract_create_tx, <<>>}) do
      :"$end_of_table" -> nil
      {^txi, :contract_create_tx, pubkey} -> pubkey
      {_txi, _tx_type, _pubkey} -> nil
    end
  end
end
