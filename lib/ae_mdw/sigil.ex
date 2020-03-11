defmodule AeMdw.Sigil do
  def sigil_t(string, []),
    do: string |> String.to_existing_atom() |> AeMdw.Db.Model.table()
end
