defmodule AeMdw.Db.Stream.Tx do
  alias AeMdw.Db.Model
  import AeMdw.Db.Util

  @tab Model.Tx

  ################################################################################

  def normalize_query(nil),
    do: nil

  def roots(nil),
    do: nil

  def full_key(sort_k, nil) when is_integer(sort_k),
    do: sort_k

  def full_key(sort_k, nil) when sort_k == <<>> or sort_k === -1,
    do: sort_k

  def first_entry(Progress), do: first(@tab)
  def first_entry(_, Degress), do: last(@tab)

  def entry(_, i, Progress) when is_integer(i),
    do: (read_tx(i) == [] && next(@tab, i)) || i

  def entry(_, i, Degress) when is_integer(i),
    do: (read_tx(i) == [] && prev(@tab, i)) || i

  def key_checker(_),
    do: fn x ->
      r = is_integer(x)
      "KEYCHK A: #{inspect(x)} -> #{r}" |> AeMdw.Util.prx()
      r
    end

  def key_checker(_, Progress, mark) when is_integer(mark),
    do: &(&1 <= mark)

  def key_checker(_, Degress, mark) when is_integer(mark),
    do: &(&1 >= mark)

  def key_checker(_, _, nil),
    do: key_checker(nil)
end
