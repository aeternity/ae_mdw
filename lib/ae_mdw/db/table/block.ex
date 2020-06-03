defmodule AeMdw.Db.Stream.Block do
  alias AeMdw.Db.Model
  import AeMdw.Db.Util

  @tab Model.Block

  ################################################################################

  def normalize_query(nil),
    do: nil

  def roots(nil),
    do: nil

  def full_key(sort_k, nil) when is_integer(sort_k),
    do: {sort_k, -1}

  def full_key({_, _} = sort_k, nil),
    do: sort_k

  def full_key(-1, nil),
    do: {first_gen(), -1}

  def full_key(<<>>, nil),
    do: {last_gen(), -1}

  def first_entry(Progress), do: first(@tab)
  def first_entry(Degress), do: last(@tab)

  def entry(nil, i, Progress) when is_integer(i),
    do: (read(@tab, {i, -1}) == [] && next(@tab, {i, -1})) || {i, -1}

  def entry(nil, i, Degress) when is_integer(i),
    do: (read(@tab, {i, -1}) == [] && prev(@tab, {i, -1})) || {i, -1}

  def key_checker(_),
    do: fn
      {_, _} -> true
      _ -> false
    end

  def key_checker(_, Progress, mark) when is_integer(mark),
    do: fn
      {kbi, _} -> kbi <= mark
      _ -> false
    end

  def key_checker(_, Progress, {_, _} = mark),
    do: fn
      {_, _} = bi -> bi <= mark
      _ -> false
    end

  def key_checker(_, Degress, mark) when is_integer(mark),
    do: fn
      {kbi, _} -> kbi >= mark
      _ -> false
    end

  def key_checker(_, Degress, {_, _} = mark),
    do: fn
      {_, _} = bi -> bi >= mark
      _ -> false
    end

  def key_checker(_, _, nil),
    do: key_checker(nil)
end
