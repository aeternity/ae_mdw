defmodule AeMdw.Db.Origin do
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Db.Util

  ##########

  def tx_index({:contract, id}) do
    pk = Validate.id!(id)

    case prev(Model.Origin, {:contract, pk, <<>>}) do
      :"$end_of_table" -> nil
      {:contract, ^pk, txi} -> txi
    end
  end
end
