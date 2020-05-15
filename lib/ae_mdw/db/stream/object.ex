defmodule AeMdw.Db.Stream.Object do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model

  import AeMdw.{Util, Db.Util}

  @tab Model.Object

  ################################################################################

  def normalize_query(nil),
    do:
      raise(ArgumentError,
        message: "requires query ID* | {:ID_TYPE...} | {:TYPE_ID...} | [QUERY*]"
      )

  # does not validate IDs and TYPEs, trusted!
  def normalize_query({:roots, %MapSet{} = m}),
    do: m

  def normalize_query({:id_type, %{} = id_type}),
    do: roots_from(id_type, &flip_tuple/1)

  def normalize_query({:type_id, %{} = type_id}),
    do: roots_from(type_id, &id/1)

  def normalize_query({:id_type, id, type}),
    do: MapSet.new(validate_product(type, id))

  def normalize_query({:type_id, type, id}),
    do: MapSet.new(validate_product(type, id))

  def normalize_query({id, type}),
    do: MapSet.new(validate_product(type, id))

  def normalize_query(id) when not is_list(id),
    do: MapSet.new(validate_product(AE.tx_types(), id))

  def normalize_query(xs) when is_list(xs) do
    xs
    |> Stream.map(&normalize_query/1)
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  def roots(%MapSet{} = set), do: set

  def full_key(sort_k, {type, <<_::256>> = pubkey}) when is_integer(sort_k) and is_atom(type),
    do: {type, pubkey, sort_k}

  def full_key(sort_k, {type, <<_::256>> = pubkey}) when sort_k == <<>> or sort_k === -1,
    do: {type, pubkey, sort_k}

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
    do: fn
      {^type, ^pubkey, _} -> true
      _ -> false
    end

  def key_checker({type, pubkey}, Progress, mark) when is_integer(mark),
    do: fn
      {^type, ^pubkey, i} -> i <= mark
      _ -> false
    end

  def key_checker({type, pubkey}, Degress, mark) when is_integer(mark),
    do: fn
      {^type, ^pubkey, i} -> i >= mark
      _ -> false
    end

  def key_checker({type, pubkey}, _, nil),
    do: key_checker({type, pubkey})

  ##########

  defp validate_product({type, id}),
    do: validate_product(type, id)

  defp validate_product(type, id) do
    tys = Enum.map(to_list_like(type), &Validate.tx_type!/1)
    ids = Enum.map(to_list_like(id), &Validate.id!/1)
    Stream.flat_map(tys, fn ty -> Stream.map(ids, fn id -> {ty, id} end) end)
  end

  defp roots_from(mapping, tuple_fun) do
    merger = &MapSet.union(MapSet.new(validate_product(tuple_fun.(&1))), &2)
    Enum.reduce(mapping, MapSet.new(), merger)
  end
end
