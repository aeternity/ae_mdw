defmodule AeMdw.Db.Stream.Field do
  alias AeMdw.Db.Model

  import AeMdw.Db.Util

  @tab Model.Field

  ################################################################################

  def normalize_query(nil),
    do: raise(ArgumentError, message: "requires query")

  # does not validate IDs and TYPEs, trusted!
  def normalize_query({:roots, %MapSet{} = m}),
    do: m

  def roots(%MapSet{} = set), do: set

  def full_key(sort_k, {type, pos, <<_::256>> = pubkey})
      when is_integer(sort_k) and is_integer(pos) and is_atom(type),
      do: {type, pos, pubkey, sort_k}

  def full_key(sort_k, {type, pos, <<_::256>> = pubkey}) when sort_k == <<>> or sort_k === -1,
    do: {type, pos, pubkey, sort_k}

  def entry({type, pos, <<_::256>> = pubkey}, i, kind)
      when is_atom(type) and is_integer(i) do
    k = {type, pos, pubkey, i}

    case read(@tab, k) do
      [_] -> k
      [] when kind == Progress -> next(@tab, k)
      [] when kind == Degress -> prev(@tab, k)
    end
  end

  def entry({type, pos, <<_::256>> = pubkey}, Progress, Progress) when is_atom(type),
    do: next(@tab, {type, pos, pubkey, -1})

  def entry({type, pos, <<_::256>> = pubkey}, Degress, Degress) when is_atom(type),
    do: prev(@tab, {type, pos, pubkey, <<>>})

  def key_checker({type, pos, pubkey}),
    do: fn
      {^type, ^pos, ^pubkey, _} -> true
      _ -> false
    end

  def key_checker({type, pos, pubkey}, Progress, mark) when is_integer(mark),
    do: fn
      {^type, ^pos, ^pubkey, i} -> i <= mark
      _ -> false
    end

  def key_checker({type, pos, pubkey}, Degress, mark) when is_integer(mark),
    do: fn
      {^type, ^pos, ^pubkey, i} -> i >= mark
      _ -> false
    end

  def key_checker({type, pos, pubkey}, _, nil),
    do: key_checker({type, pos, pubkey})

  ##########

  # defp validate_product({type, id}),
  #   do: validate_product(type, id)

  # defp validate_product(type, id) do
  #   tys = Enum.map(to_list_like(type), &Validate.tx_type!/1)
  #   ids = Enum.map(to_list_like(id), &Validate.id!/1)
  #   Stream.flat_map(tys, fn ty -> Stream.map(ids, fn id -> {ty, id} end) end)
  # end

  # defp roots_from(mapping, tuple_fun) do
  #   merger = &MapSet.union(MapSet.new(validate_product(tuple_fun.(&1))), &2)
  #   Enum.reduce(mapping, MapSet.new(), merger)
  # end
end
