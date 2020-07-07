defmodule AeMdw.Db.Stream.Resource do
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Node, as: AE

  import AeMdw.{Util, Db.Util}
  import AeMdw.Db.Stream.Resource.Util

  ################################################################################

  def map(scope, tab, mapper, query, prefer_order) do
    {scope, order} = DBS.Scope.scope(scope, tab, prefer_order)
    mod = AE.stream_mod(tab)
    query = mod.normalize_query(query)
    {constructor, state} = init(scope, mod, order, query)
    constructor.(state, tab, order, mapper)
  end

  defp init(nil, _mod, _order, _query),
    do: {&empty/4, nil}

  defp init({:range, range} = scope, mod, order, query) do
    case mod.roots(query) do
      [] ->
        {&empty/4, nil}

      nil ->
        init_from_scope(scope, mod, order)

      roots ->
        scope_check = DBS.Scope.checker(scope, order)
        conts = continuations(roots, range, scope_check, mod, order, &put_kv/2)

        case :gb_sets.size(conts) do
          0 -> {&empty/4, nil}
          1 -> {&simple/4, elem(:gb_sets.smallest(conts), 1)}
          _ -> {&complex/4, conts}
        end
    end
  end

  defp init(single_val, mod, order, query),
    do: init({:range, {single_val, single_val}}, mod, order, query)

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

  ################################################################################

  def empty(nil, _tab, _order, _mapper),
    do: empty_resource()

  def simple(init_state, tab, _order, mapper),
    do: simple_resource(init_state, tab, mapper)

  ################################################################################

  def complex(conts, tab, order, mapper) do
    cont_pop = set_taker(order)

    Stream.resource(
      fn -> {conts, nil} end,
      fn {conts, last_sort_k} -> do_complex(tab, conts, cont_pop, mapper, last_sort_k) end,
      &AeMdw.Util.id/1
    )
  end

  def do_complex(_tab, {0, nil}, _cont_pop, _mapper, _last_sort_k),
    do: {:halt, :done}

  def do_complex(tab, conts, cont_pop, mapper, last_sort_k),
    do: do_complex(tab, nil, nil, conts, cont_pop, mapper, last_sort_k)

  def do_complex(_tab, _key, nil, {0, nil}, _cont_pop, _mapper, _last_sort_k),
    do: {:halt, :done}

  def do_complex(tab, nil, nil, conts, cont_pop, mapper, last_sort_k) do
    {{_sort_k, {key, advance}}, conts} = cont_pop.(conts)
    do_complex(tab, key, advance, conts, cont_pop, mapper, last_sort_k)
  end

  def do_complex(tab, key, advance, conts, cont_pop, mapper, last_sort_k) do
    sort_k = sort_key(key)

    case sort_k === last_sort_k do
      false ->
        case {read(tab, key), advance.(tab, key)} do
          {[x], {:cont, next_key}} ->
            case mapper.(x) do
              nil ->
                do_complex(tab, next_key, advance, conts, cont_pop, mapper, sort_k)

              val ->
                {[val], {add_cursor({next_key, advance}, conts), sort_k}}
            end

          {[], {:cont, next_key}} ->
            do_complex(tab, next_key, advance, conts, cont_pop, mapper, sort_k)

          {[x], {:halt, _}} ->
            case mapper.(x) do
              nil -> {:halt, :done}
              val -> {[val], {conts, sort_k}}
            end

          {[], {:halt, _}} ->
            {:halt, :done}
        end

      true ->
        case advance.(tab, key) do
          {:cont, next_key} ->
            do_complex(tab, next_key, advance, conts, cont_pop, mapper, sort_k)

          {:halt, _} ->
            do_complex(tab, nil, nil, conts, cont_pop, mapper, sort_k)
        end
    end
  end
end
