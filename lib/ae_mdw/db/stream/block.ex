defmodule AeMdw.Db.Stream.Block do
  alias AeMdw.Db.Stream, as: DBS
  import AeMdw.{Sigil, Db.Util, Util}

  @tab ~t[block]

  ################################################################################

  def roots(%{}),
    do: nil

  def entry(nil, i, Progress) when is_integer(i),
    do: read(@tab, {i, -1}) == [] && next(@tab, {i, -1}) || {i, -1}
  def entry(nil, i, Degress) when is_integer(i),
    do: read(@tab, {i, -1}) == [] && prev(@tab, {i, -1}) || {i, -1}
  def entry(_, Progress, Progress),
    do: first(@tab)
  def entry(_, Degress, Degress),
    do: last(@tab)

  def key_checker(_),
    do: fn {_, _} -> true; _ -> false end
  def key_checker(_, Progress, mark) when is_integer(mark),
    do: fn {kbi, _} -> kbi <= mark; _ -> false end
  def key_checker(_, Degress, mark) when is_integer(mark),
    do: fn {kbi, _} -> kbi >= mark; _ -> false end

end
