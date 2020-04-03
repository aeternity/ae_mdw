defmodule AeMdw.Db.Stream.Tx do
  require Ex2ms
  require AeMdw.Db.Model

  alias AeMdw.Db.Model

  import AeMdw.{Sigil, Util, Db.Util}

  @tab ~t[tx]

  ################################################################################

  def roots(%{}),
    do: nil

  def entry(_, i, Progress) when is_integer(i),
    do: read_tx(i) == [] && next(@tab, i) || i
  def entry(_, i, Degress) when is_integer(i),
    do: read_tx(i) == [] && prev(@tab, i) || i
  def entry(_, Progress, Progress),
    do: first(@tab)
  def entry(_, Degress, Degress),
    do: last(@tab)

  def key_checker(_),
    do: &is_integer/1
  def key_checker(_, Progress, mark) when is_integer(mark),
    do: &(&1 <= mark)
  def key_checker(_, Degress, mark) when is_integer(mark),
    do: &(&1 >= mark)

end
