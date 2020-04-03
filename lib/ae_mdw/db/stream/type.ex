defmodule AeMdw.Db.Stream.Type do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Stream

  import AeMdw.{Sigil, Util, Db.Util}

  @tab ~t[type]

  ################################################################################

  def roots(%{type: type} = ctx) do
    case Enum.to_list(to_list_like(type)) do
      [_|_] = type -> Enum.map(type, &Validate.tx_type!/1)
      [] -> raise AeMdw.Error.Input, message: ":type not found"
    end
  end
  def roots(%{}),
    do: AE.tx_types()

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
    do: fn {^type, _b} -> true; _ -> false end
  def key_checker(type, Progress, mark) when is_integer(mark),
    do: fn {^type, i} -> i <= mark; _ -> false end
  def key_checker(type, Degress, mark) when is_integer(mark),
    do: fn {^type, i} -> i >= mark; _ -> false end

end
