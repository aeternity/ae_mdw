defmodule AeMdw.Db.Origin do
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  ################################################################################

  def tx_index({:contract, id}) do
    pk = Validate.id!(id)
    tab = ~t[origin]

    case prev(tab, {:contract, pk, <<>>}) do
      :"$end_of_table" -> nil
      {:contract, ^pk, txi} -> txi
    end
  end
end
