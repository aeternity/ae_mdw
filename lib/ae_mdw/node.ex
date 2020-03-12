defmodule AeMdw.Node do

  alias AeMdw.Db.Model

  def tx_types(),
    do: Model.get_meta!(:tx_types)

  def tx_mod(tx_type),
    do: Model.get_meta!({:tx_mod, tx_type})

  def tx_ids(tx_type),
    do: Model.get_meta!({:tx_ids, tx_type})

  def tx_fields(tx_type),
    do: Model.get_meta!({:tx_fields, tx_type})

  def tx_to_map(tx_type, tx_rec) do
    tx_fields(tx_type)
    |> Stream.with_index(1)
    |> Enum.reduce(%{},
         fn {field, pos}, acc ->
           put_in(acc[field], elem(tx_rec, pos))
         end)
  end

end
