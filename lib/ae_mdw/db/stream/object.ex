defmodule AeMdw.Db.Stream.Object do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate

  import AeMdw.{Sigil, Util, Db.Util}

  @tab ~t[object]

  ################################################################################

  def roots(%{type_id: %{} = type_id}) do
    merger = &MapSet.union(MapSet.new(product(&1)), &2)
    Enum.reduce(type_id, MapSet.new(), merger)
  end
  def roots(%{id_type: %{} = id_type}) do
    merger = &MapSet.union(MapSet.new(product(flip_tuple(&1))), &2)
    Enum.reduce(id_type, MapSet.new(), merger)
  end
  def roots(%{type: type, id: id}),
    do: product(type, id) |> MapSet.new
  def roots(%{id: id} = ctx),
    do: roots(Map.put(ctx, :type, AE.tx_types()))
  def roots(%{} = ctx),
    do: raise AeMdw.Error.Input, message: ":id not found"


  def entry({type, <<_::256>> = pubkey}, i, kind) when is_atom(type) and is_integer(i) do
    k = {type, pubkey, i}
    case read(@tab, k) do
      [_] -> k
      [] when kind == Progress -> next(@tab, k)
      [] when kind == Degress -> prev(@tab, k)
    end
  end
  def entry({type, <<_::256>> = pubkey}, Progress, Progress) when is_atom(type),
    do: next(@tab, {type, pubkey, -1})
  def entry({type, <<_::256>> = pubkey}, Degress, Degress) when is_atom(type),
    do: prev(@tab, {type, pubkey, <<>>})


  def key_checker({type, pubkey}),
    do: fn {^type, ^pubkey, _} -> true; _ -> false end
  def key_checker({type, pubkey}, Progress, mark) when is_integer(mark),
    do: fn {^type, ^pubkey, i} -> i <= mark; _ -> false end
  def key_checker({type, pubkey}, Degress, mark) when is_integer(mark),
    do: fn {^type, ^pubkey, i} -> i >= mark; _ -> false end

  ##########

  defp product({type, id}),
    do: product(type, id)
  defp product(type, id) do
    tys = Enum.map(to_list_like(type), &Validate.tx_type!/1)
    ids = Enum.map(to_list_like(id), &Validate.id!/1)
    Stream.flat_map(tys, fn ty -> Stream.map(ids, fn id -> {ty, id} end) end)
  end

end
