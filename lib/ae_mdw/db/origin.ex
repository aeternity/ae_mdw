defmodule AeMdw.Db.Origin do
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  require Model

  import AeMdw.{Util, Db.Util}

  ##########

  def block_index({:contract, id}),
    do: map_some(tx_index({:contract, id}), &Model.tx(read_tx!(&1), :block_index))

  def tx_index({:contract, id}) do
    pk = Validate.id!(id)

    case prev(Model.Origin, {:contract_create_tx, pk, <<>>}) do
      :"$end_of_table" -> nil
      {:contract_create_tx, ^pk, txi} -> txi
    end
  end

  def pubkey({:contract, txi}) do
    case next(Model.RevOrigin, {txi, :contract_create_tx, <<>>}) do
      :"$end_of_table" -> nil
      {^txi, :contract_create_tx, pubkey} -> pubkey
    end
  end
end
