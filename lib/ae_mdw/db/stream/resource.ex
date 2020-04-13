defmodule AeMdw.Db.Stream.Resource do
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Node, as: AE

  import AeMdw.Db.Util

  ################################################################################

  def map(scope, tab, mapper, query, prefer_order) do
    {scope, order} = DBS.Scope.scope(scope, tab, prefer_order)
    mod = AE.stream_mod(tab)
    query = mod.normalize_query(query)
    {constructor, state} = init(scope, mod, order, query, prefer_order)
    constructor.(state, tab, order, mapper)
  end

  defp init(nil, _mod, _order, _query, _prefer_order),
    do: {&empty/4, nil}

  defp init({:range, range} = scope, mod, order, query, _prefer_order) do
    case mod.roots(query) do
      [] ->
        {&empty/4, nil}

      nil ->
        init_from_scope(scope, mod, order)

      # root looks like MapSet<{type, pubkey}>
      roots ->
        # roots |> prx("##############################")
        scope_check = DBS.Scope.checker(scope, order)

        conts =
          roots
          |> Stream.map(&cursor(&1, range, mod, order))
          |> Stream.filter(fn
            nil -> false
            _ -> true
          end)
          |> Stream.filter(fn {key, _advance} -> scope_check.(sort_key(key)) end)

        conts =
          conts
          |> Enum.reduce(%{}, &put_kv/2)
          |> Enum.reduce(:gb_sets.new(), &add_cursor/2)

        case :gb_sets.size(conts) do
          0 -> {&empty/4, nil}
          1 -> {&simple/4, elem(:gb_sets.smallest(conts), 1)}
          _ -> {&complex/4, conts}
        end
    end
  end

  defp init(single_val, mod, order, query, prefer_order),
    do: init({:range, {single_val, single_val}}, mod, order, query, prefer_order)

  # defp init_from_scope({:exact, k}, mod, _order),
  #   do: {&simple/4, {mod.full_key(k, nil), &halter/2}}

  defp init_from_scope({:range, {from, to}}, mod, Progress),
    do:
      {&simple/4,
       {mod.full_key(from || -1, nil), advance_fn(&next/2, mod.key_checker(nil, Progress, to))}}

  defp init_from_scope({:range, {from, to}}, mod, Degress),
    do:
      {&simple/4,
       {mod.full_key(from || <<>>, nil), advance_fn(&prev/2, mod.key_checker(nil, Degress, to))}}

  defp init_from_scope({:range, nil}, mod, Progress),
    do: {&simple/4, {mod.full_key(-1, nil), advance_fn(&next/2, mod.key_checker(nil))}}

  defp init_from_scope({:range, nil}, mod, Degress),
    do: {&simple/4, {mod.full_key(<<>>, nil), advance_fn(&prev/2, mod.key_checker(nil))}}

  #  defp halter(_tab, _succ_k), do: {:halt, :exact}

  defp add_cursor({key, advance}, acc),
    do: :gb_sets.add({sort_key(key), {key, advance}}, acc)

  ################################################################################

  def cursor(root, {i, limit}, mod, Progress) when i <= limit do
    chk = mod.key_checker(root, Progress, limit)
    do_cursor(mod.entry(root, i, Progress), chk, advance_fn(&next/2, chk))
  end

  def cursor(root, {i, limit}, mod, Degress) when i >= limit do
    chk = mod.key_checker(root, Degress, limit)
    do_cursor(mod.entry(root, i, Degress), chk, advance_fn(&prev/2, chk))
  end

  def do_cursor(:"$end_of_table", _checker, _advance),
    do: nil

  def do_cursor(key, _checker, _advance) when elem(key, 0) == :"$end_of_table",
    do: nil

  def do_cursor(key, checker, advance),
    do: (checker.(key) && {key, advance}) || nil

  def advance_fn(succ, key_checker) do
    fn tab, key ->
      case succ.(tab, key) do
        :"$end_of_table" ->
          {:halt, :eot}

        next_key ->
          case key_checker.(next_key) do
            true -> {:cont, next_key}
            false -> {:halt, :keychk}
          end
      end
    end
  end

  def sort_key(i) when is_integer(i), do: i
  def sort_key({_, i}), do: i
  def sort_key({_, _, i}), do: i

  def full_key(root, i) when is_tuple(root),
    do: Tuple.append(root, i)

  def full_key(root, i),
    do: {root, i}

  def put_kv({k, v}, map), do: Map.put(map, k, v)

  def set_taker(Progress), do: &:gb_sets.take_smallest/1
  def set_taker(Degress), do: &:gb_sets.take_largest/1

  ################################################################################

  def empty(nil, _tab, _kind, _mapper) do
    Stream.resource(
      fn -> nil end,
      fn nil -> {:halt, :empty} end,
      &AeMdw.Util.id/1
    )
  end

  ################################################################################

  def simple(init_state, tab, _kind, mapper) do
    Stream.resource(
      fn -> init_state end,
      fn {x, advance} -> do_simple(tab, x, advance, mapper) end,
      &AeMdw.Util.id/1
    )
  end

  def do_simple(_tab, _key, nil, _mapper),
    do: {:halt, :done}

  def do_simple(tab, key, advance, mapper) do
    case {read(tab, key), advance.(tab, key)} do
      {[x], {:cont, next_key}} ->
        case mapper.(x) do
          nil -> do_simple(tab, next_key, advance, mapper)
          val -> {[val], {next_key, advance}}
        end

      {[], {:cont, next_key}} ->
        do_simple(tab, next_key, advance, mapper)

      {[x], {:halt, _}} ->
        case mapper.(x) do
          nil -> {:halt, :done}
          val -> {[val], {:eot, nil}}
        end

      {[], {:halt, _}} ->
        {:halt, :done}
    end
  end

  ################################################################################

  def complex(conts, tab, kind, mapper) do
    cont_pop = set_taker(kind)

    Stream.resource(
      fn -> conts end,
      fn conts -> do_complex(tab, conts, cont_pop, mapper) end,
      &AeMdw.Util.id/1
    )
  end

  def do_complex(_tab, {0, nil}, _cont_pop, _mapper),
    do: {:halt, :done}

  def do_complex(tab, conts, cont_pop, mapper),
    do: do_complex(tab, nil, nil, conts, cont_pop, mapper)

  def do_complex(_tab, _key, nil, {0, nil}, _cont_pop, _mapper),
    do: {:halt, :done}

  def do_complex(tab, nil, nil, conts, cont_pop, mapper) do
    {{_sort_key, {key, advance}}, conts} = cont_pop.(conts)
    do_complex(tab, key, advance, conts, cont_pop, mapper)
  end

  def do_complex(tab, key, advance, conts, cont_pop, mapper) do
    case {read(tab, key), advance.(tab, key)} do
      {[x], {:cont, next_key}} ->
        case mapper.(x) do
          nil ->
            do_complex(tab, next_key, advance, conts, cont_pop, mapper)

          val ->
            {[val], add_cursor({next_key, advance}, conts)}
        end

      {[], {:cont, next_key}} ->
        do_complex(tab, next_key, advance, conts, cont_pop, mapper)

      {[x], {:halt, _}} ->
        case mapper.(x) do
          nil -> {:halt, :done}
          val -> {[val], conts}
        end

      {[], {:halt, _}} ->
        {:halt, :done}
    end
  end
end
