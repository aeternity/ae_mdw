defmodule AeMdw.Db.Stream.Type do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  import AeMdw.{Util, Db.Util}

  @tab Model.Type

  ################################################################################

  def normalize_query(nil),
    do: AE.tx_types()

  def normalize_query(types),
    do: Enum.map(types, &Validate.tx_type!/1)

  def roots(types) do
    true = Enum.count(types) > 0
    types
  end

  def full_key(sort_k, type) when is_integer(sort_k) and sort_k >= 0 and is_atom(type),
    do: {type, sort_k}

  def full_key(sort_k, type) when sort_k == <<>> or sort_k === -1,
    do: {type, sort_k}

  def entry(type, i, kind) when is_atom(type) and is_integer(i) do
    case read(@tab, {type, i}) do
      [_] -> {type, i}
      [] when kind == Progress -> next(@tab, {type, i})
      [] when kind == Degress -> prev(@tab, {type, i})
    end
  end

  def entry(type, Progress, Progress) when is_atom(type),
    do: next(@tab, {type, -1})

  def entry(type, Degress, Degress) when is_atom(type),
    do: prev(@tab, {type, <<>>})

  def key_checker(type),
    do: fn
      {^type, _b} -> true
      _ -> false
    end

  def key_checker(type, Progress, mark) when is_integer(mark),
    do: fn
      {^type, i} -> i <= mark
      _ -> false
    end

  def key_checker(type, Degress, mark) when is_integer(mark),
    do: fn
      {^type, i} -> i >= mark
      _ -> false
    end

  def key_checker(type, _, nil),
    do: key_checker(type)
end
