defmodule AeMdw.Db.Stream.Resource.Util do
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Db.Util

  ##########

  def add_cursor({key, val}, acc),
    do: :gb_sets.add({sort_key(key), {key, val}}, acc)

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

  def advance_signal_fn(succ, key_checker) do
    fn tab, key ->
      succ = succ.(tab, key)

      case succ do
        :"$end_of_table" ->
          {:halt, :eot}

        next_key ->
          case key_checker.(next_key) do
            true -> {:cont, {true, next_key}}
            :skip -> {:cont, {:skip, next_key}}
            false -> {:halt, :keychk}
          end
      end
    end
  end

  def sort_key(i) when is_integer(i), do: i
  def sort_key({_, i}), do: i
  def sort_key({_, _, i}), do: i
  def sort_key({_, _, _, i}), do: i

  def full_key(root, i) when is_tuple(root),
    do: Tuple.append(root, i)

  def full_key(root, i),
    do: {root, i}

  def put_kv({k, v}, map), do: Map.put(map, k, v)

  def set_taker(Progress), do: &:gb_sets.take_smallest/1
  def set_taker(Degress), do: &:gb_sets.take_largest/1

  def continuations(roots, range, scope_check, mod, order, put_kv) do
    roots
    |> Stream.map(&cursor(&1, range, mod, order))
    |> Stream.reject(&is_nil/1)
    |> Stream.filter(fn {key, _advance} -> scope_check.(sort_key(key)) end)
    |> Enum.reduce(%{}, put_kv)
    |> Enum.reduce(:gb_sets.new(), &add_cursor/2)
  end

  ##########

  def empty_resource() do
    Stream.resource(
      fn -> nil end,
      fn nil -> {:halt, :empty} end,
      &AeMdw.Util.id/1
    )
  end

  ##########

  def simple_resource(init_state, tab, mapper) do
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

  ##########

  def signalled_resource(init_state, tab, mapper) do
    Stream.resource(
      fn -> init_state end,
      fn {x, sig_advance} -> do_signalled(tab, x, sig_advance, mapper) end,
      &AeMdw.Util.id/1
    )
  end

  def do_signalled(_tab, _key, nil, _mapper),
    do: {:halt, :done}

  def do_signalled(tab, {:skip, key}, sig_advance, mapper) do
    case sig_advance.(tab, key) do
      {:halt, _} -> {:halt, :done}
      {:cont, sig_next_key} -> do_signalled(tab, sig_next_key, sig_advance, mapper)
    end
  end

  def do_signalled(tab, {true, key}, sig_advance, mapper) do
    case {read(tab, key), sig_advance.(tab, key)} do
      {[x], {:cont, next_key}} ->
        case mapper.(x) do
          nil -> do_signalled(tab, next_key, sig_advance, mapper)
          val -> {[val], {next_key, sig_advance}}
        end

      {[], {:cont, next_key}} ->
        do_signalled(tab, next_key, sig_advance, mapper)

      {[x], {:halt, _}} ->
        case mapper.(x) do
          nil -> {:halt, :done}
          val -> {[val], {:eot, nil}}
        end

      {[], {:halt, _}} ->
        {:halt, :done}
    end
  end
end
