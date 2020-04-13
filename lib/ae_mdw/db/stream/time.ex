defmodule AeMdw.Db.Stream.Time do
  alias AeMdw.Db.Model
  import AeMdw.Db.Util

  @tab Model.Time

  ################################################################################

  def normalize_query(nil),
    do: nil

  def roots(nil),
    do: nil

  def full_key({_,_} = sort_k, nil),
    do: sort_k
  def full_key(sort_k, nil) when sort_k == <<>> or sort_k === -1,
    do: sort_k


  def first_entry(Progress),
    do: first(@tab)
  def first_entry(Degress),
    do: last(@tab)

  def entry(_, i, Progress) when is_integer(i),
    do: next(@tab, {i, -1})
  def entry(_, i, Degress) when is_integer(i),
    do: prev(@tab, {i, <<>>})

  def key_checker(_),
    do: fn {_,_} -> true; _ -> false end
  def key_checker(_, Progress, mark),
    do: fn {_,_} = i -> i <= mark end
  def key_checker(_, Degress, mark),
    do: fn {_,_} = i -> i >= mark end
  def key_checker(_, _, nil),
    do: key_checker(nil)

end
