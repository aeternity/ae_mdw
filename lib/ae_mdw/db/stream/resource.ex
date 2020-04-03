defmodule AeMdw.Db.Stream.Resource do
  alias AeMdw.Node, as: AE

  import AeMdw.Db.Util

  ################################################################################

  def cursor(mod, :all, root, kind),
    do: cursor!(mod, root, kind, kind)
  def cursor(mod, {:from, from}, root, kind),
    do: cursor!(mod, root, from, kind)
  def cursor(mod, {:to, to}, root, kind),
    do: cursor!(mod, root, to, kind)
  def cursor(mod, {from, to}, root, Progress) when from <= to,
    do: cursor!(mod, root, from, to, Progress)
  def cursor(mod, {from, to}, root, Progress) when from > to,
    do: cursor!(mod, root, to, from, Progress)
  def cursor(mod, {from, to}, root, Degress) when from >= to,
    do: cursor!(mod, root, from, to, Degress)
  def cursor(mod, {from, to}, root, Degress) when from < to,
    do: cursor!(mod, root, to, from, Degress)
  def cursor(mod, %{__struct__: Range, first: f, last: l}, root, kind),
    do: cursor(mod, {f, l}, root, kind)

  def cursor!(mod, root, i, Progress) do
    chk = mod.key_checker(root)
    do_cursor!(mod.entry(root, i, Progress), chk, advance_fn(&next/2, chk))
  end
  def cursor!(mod, root, i, Degress) do
    chk = mod.key_checker(root)
    do_cursor!(mod.entry(root, i, Degress), chk, advance_fn(&prev/2, chk))
  end
  def cursor!(mod, root, i, limit, Progress) do
    chk = mod.key_checker(root, Progress, limit)
    do_cursor!(mod.entry(root, i, Progress), chk, advance_fn(&next/2, chk))
  end
  def cursor!(mod, root, i, limit, Degress) do
    chk = mod.key_checker(root, Degress, limit)
    do_cursor!(mod.entry(root, i, Degress), chk, advance_fn(&prev/2, chk))
  end

  def do_cursor!(:"$end_of_table", _checker, _advance),
    do: nil
  def do_cursor!(key, _checker, _advance) when elem(key, 0) == :"$end_of_table",
    do: nil
  def do_cursor!(key, checker, advance),
    do: checker.(key) && {key, advance} || nil


  def scope_checker(:all, _kind),
    do: fn _ -> true end
  def scope_checker({:from, from}, Progress),
    do: fn i -> i >= from end
  def scope_checker({:from, from}, Degress),
    do: fn i -> i <= from end
  def scope_checker({:to, to}, Progress),
    do: fn i -> i <= to end
  def scope_checker({:to, to}, Degress),
    do: fn i -> i >= to end
  def scope_checker({from, to}, Progress) when from <= to,
    do: fn i -> i >= from && i <= to end
  def scope_checker({from, to}, Progress) when from > to,
    do: fn i -> i >= to && i <= from end
  def scope_checker({from, to}, Degress) when from >= to,
    do: fn i -> i <= from && i >= to end
  def scope_checker({from, to}, Degress) when from < to,
    do: fn i -> i >= from && i <= to end
  def scope_checker(%{__struct__: Range, first: f, last: l}, kind),
    do: scope_checker({f, l}, kind)
  def scope_checker({f, l}, kind),
    do: raise AeMdw.Error.Input.Scope, value: {{f, l}, kind}


  def advance_fn(succ, key_checker) do
    fn tab, key ->
      case succ.(tab, key) do
        :"$end_of_table" -> {:halt, :eot}
        next_key ->
          case key_checker.(next_key) do
            true -> {:cont, next_key}
            false -> {:halt, :keychk}
          end
      end
    end
  end

  def map(scope, tab, ctx, kind, mapper) do
    {mode, init_state} = cursors(scope, tab, ctx, kind)
    mode.(init_state, tab, kind, mapper)
  end


  def cursors(scope, tab, ctx, kind) do
    mod = AE.stream_mod(tab)
    case mod.roots(ctx) do
      [] ->
        {&empty/4, nil}
      nil ->
        init = cursor(mod, scope, nil, kind)
        init && {&simple/4, init} || {&empty/4, nil}
      [x] ->
        init = cursor(mod, scope, x, kind)
        init && {&simple/4, init} || {&empty/4, nil}
      roots ->
        scope_check = scope_checker(scope, kind)
        conts =
          roots
          |> Stream.map(&cursor(mod, scope, &1, kind))
          |> Stream.filter(fn nil -> false; _ -> true end)
          |> Stream.filter(fn {key, _advance} -> scope_check.(sort_key(key)) end)
          |> Enum.reduce(%{}, &put_kv/2)
          |> Enum.reduce(:gb_sets.new(),
               fn {key, advance}, set ->
                 :gb_sets.add({sort_key(key), {key, advance}}, set)
               end)
        {&complex/4, conts}
    end
  end

  def sort_key(x) when is_integer(x), do: x
  def sort_key({_, x}), do: x
  def sort_key({_, _, x}), do: x

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
            {[val], :gb_sets.add({sort_key(next_key), {next_key, advance}}, conts)}
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
