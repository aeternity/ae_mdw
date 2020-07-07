defmodule AeMdw.Db.Stream.Resource.Or do
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Model
  alias AeMdw.Node, as: AE

  require Model

  import AeMdw.Db.Util
  import AeMdw.Db.Stream.Resource.Util

  ##########

  def map(scope, mapper, {types, or_roots_checks}, prefer_order) do
    case Enum.count(types) do
      0 ->
        map1(scope, or_roots_checks, prefer_order)

      _ ->
        filter_typed_root = fn {:roots, roots, check_fun} ->
          filtered = Enum.reject(roots, fn {type, _, _} -> type in types end)
          (filtered != [] && [{:roots, filtered, check_fun}]) || []
        end

        case Enum.flat_map(or_roots_checks, filter_typed_root) do
          [] ->
            DBS.map(scope, mapper, {%{}, types}, prefer_order)

          [_ | _] = or_roots_checks ->
            map1(scope, mapper, types, or_roots_checks, prefer_order)
        end
    end
  end

  def map1(scope, [_ | _] = or_roots_checks, prefer_order) do
    {conts, order} = conts_order(scope, or_roots_checks, prefer_order)
    resource(:gb_sets.size(conts), conts, order)
  end

  def map1(scope, mapper, %MapSet{} = types, [_ | _] = or_roots_checks, prefer_order) do
    {type_conts, order} = conts_order(scope, mapper, types, prefer_order)
    {field_conts, ^order} = conts_order(scope, or_roots_checks, prefer_order)
    conts = :gb_sets.union(type_conts, field_conts)
    resource(:gb_sets.size(conts), conts, order)
  end

  ##########

  def wrap_put_kv3(tab, fun),
    do: fn {key, advance}, acc -> put_kv({key, {advance, tab, fun}}, acc) end

  def conts_order(scope, mapper, %MapSet{} = types, prefer_order) do
    tab = Model.Type
    {{:range, range} = scope, order} = DBS.Scope.scope(scope, tab, prefer_order)
    mod = AE.stream_mod(tab)
    roots = mod.normalize_query(types)
    scope_check = DBS.Scope.checker(scope, order)
    mapper = DBS.Mapper.function(mapper, tab)
    {continuations(roots, range, scope_check, mod, order, wrap_put_kv3(tab, mapper)), order}
  end

  def conts_order(scope, [_ | _] = or_roots_checks, prefer_order) do
    tab = Model.Field
    {{:range, range} = scope, order} = DBS.Scope.scope(scope, tab, prefer_order)
    mod = AE.stream_mod(tab)
    scope_check = DBS.Scope.checker(scope, order)

    {for {:roots, roots, check_fun} <- or_roots_checks, reduce: :gb_sets.new() do
       acc ->
         continuations(roots, range, scope_check, mod, order, wrap_put_kv3(tab, check_fun))
         |> :gb_sets.union(acc)
     end, order}
  end

  ##########

  def resource(0, _, _),
    do: empty_resource()

  def resource(1, conts, _order) do
    [{_sort_key, {key, advance, tab, mapper}}] = :gb_sets.to_list(conts)
    simple_resource({key, advance}, tab, mapper)
  end

  def resource(_, conts, order),
    do: complex_resource(conts, order)

  ##########

  def complex_resource(conts, order) do
    cont_pop = set_taker(order)

    Stream.resource(
      fn -> {conts, nil} end,
      fn {conts, last_sort_k} -> do_complex(conts, cont_pop, last_sort_k) end,
      &AeMdw.Util.id/1
    )
  end

  def do_complex({0, nil}, _cont_pop, _last_sort_k),
    do: {:halt, :done}

  def do_complex(conts, cont_pop, last_sort_k) do
    {{_sort_k, {key, {advance, tab, mapper}}}, conts} = cont_pop.(conts)
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
                do_complex(
                  add_cursor({next_key, {advance, tab, mapper}}, conts),
                  cont_pop,
                  sort_k
                )

              val ->
                {[val], {add_cursor({next_key, {advance, tab, mapper}}, conts), sort_k}}
            end

          {[], {:cont, next_key}} ->
            do_complex(add_cursor({next_key, {advance, tab, mapper}}, conts), cont_pop, sort_k)

          {[x], {:halt, _}} ->
            case mapper.(x) do
              nil -> do_complex(conts, cont_pop, sort_k)
              val -> {[val], {conts, sort_k}}
            end

          {[], {:halt, _}} ->
            do_complex(conts, cont_pop, sort_k)
        end

      true ->
        case advance.(tab, key) do
          {:cont, next_key} ->
            do_complex(add_cursor({next_key, {advance, tab, mapper}}, conts), cont_pop, sort_k)

          {:halt, _} ->
            do_complex(conts, cont_pop, sort_k)
        end
    end
  end
end
