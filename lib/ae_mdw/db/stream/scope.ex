defmodule AeMdw.Db.Stream.Scope do
  alias AeMdw.Db.Model
  alias AeMdw.Error
  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  # second
  @time_scope_max_diff_msecs 1000

  ################################################################################

  def scope(definition, tab, order) do
    {inferred_unit, scope, final_order} =
      definition
      |> parse
      |> ordered_scope(order)

    required_unit = unit(tab)
    translation = translate({inferred_unit, scope, final_order}, required_unit)
    {translation, final_order}
  end

  def checker({:range, nil}, _order),
    do: fn _ -> true end

  def checker({:range, {nil, sort_b}}, Progress),
    do: fn i -> i <= sort_b end

  def checker({:range, {sort_a, nil}}, Progress),
    do: fn i -> i >= sort_a end

  def checker({:range, {nil, sort_b}}, Degress),
    do: fn i -> i >= sort_b end

  def checker({:range, {sort_a, nil}}, Degress),
    do: fn i -> i <= sort_a end

  def checker({:range, {sort_a, sort_b}}, Progress),
    do: fn i -> i >= sort_a && i <= sort_b end

  def checker({:range, {sort_a, sort_b}}, Degress),
    do: fn i -> i <= sort_a && i >= sort_b end

  ##########

  # txi scope
  # gen scope
  # time scope

  def units(),
    do: [:txi, :gen, :time]

  def unit(Model.Block), do: :gen
  def unit(Model.Time), do: :time
  def unit(Model.Type), do: :type
  def unit(_), do: :txi

  # %Date{}                                | <Date at 00:00, Date + 1 day>
  # x (int)                                | <x, x>
  # :forward                               | <0, last_txi>
  # :backward                              | <last_txi, 0>
  # a..b                                   | <a, b>
  # [from: nonneg_int]                     | <from, last_txi>
  # [from: nonneg_int, to: nonneg_int]     | <from, to>
  # [to: nonneg_int]                       | <first_txi, to>
  # [from: nonneg_int, downto: nonneg_int] | <from, downto>
  # [downto: nonneg_int]                   | <last_txi, downto>

  def parse(order) when order == :forward or order == :backward,
    do: do_parse({nil, order})

  def parse({unit, order}) when order == :forward or order == :backward do
    unit in units() || raise ArgumentError, message: "invalid unit #{inspect(unit)}"
    do_parse({nil, order})
  end

  def parse(%Range{} = r),
    do: do_parse({nil, normalize(r)})

  def parse([_ | _] = spec),
    do: do_parse({nil, normalize(spec)})

  def parse(%{} = spec),
    do: do_parse({nil, spec})

  def parse({key, val}) do
    case key in units() do
      true -> do_parse({key, normalize(val)})
      false -> do_parse({nil, normalize({key, val})})
    end
  end

  def parse(x) when is_integer(x),
    do: do_parse({nil, x})

  def do_parse({unit, :forward}) when is_atom(unit),
    do: {unit, nil, Progress}

  def do_parse({unit, :backward}) when is_atom(unit),
    do: {unit, nil, Degress}

  def do_parse({unit, i}) when is_atom(unit) and is_integer(i),
    do: {unit, i, Progress}

  def do_parse({unit, %Date{} = date}) when is_atom(unit),
    do: {:time, range(date), Progress}

  def do_parse({unit, %DateTime{} = time}) when is_atom(unit),
    do: {:time, msecs(time), Progress}

  def do_parse({unit, %{from: from, to: to}}) when is_atom(unit),
    do: normalize_from_to(unit, from, to)

  def do_parse({unit, %{from: from, downto: to} = spec}) when is_atom(unit) do
    case normalize_from_to(unit, from, to) do
      {_, {_, _}, Progress} ->
        raise Error.Input.Scope, value: spec

      {unit, {from, to}, Degress} ->
        {unit, {from, to}, Degress}
    end
  end

  def do_parse({unit, %{from: from}}) when is_atom(unit) and is_integer(from),
    do: {unit, {from, nil}, Progress}

  def do_parse({unit, %{to: to}}) when is_atom(unit) and is_integer(to),
    do: {unit, {0, to}, Progress}

  def do_parse({unit, %{downto: to}}) when is_atom(unit) and is_integer(to),
    do: {unit, {nil, to}, Degress}

  def normalize(%Range{} = r),
    do: %{from: r.first, to: r.last}

  def normalize({_, _} = spec),
    do: normalize([spec])

  def normalize([_ | _] = spec),
    do: kvs_to_map(spec)

  def normalize(x),
    do: x

  def normalize_from_to(unit, from, to) when is_integer(from) and is_integer(to),
    do: {unit, {from, to}, (from <= to && Progress) || Degress}

  def normalize_from_to(unit, from, nil) when is_integer(from),
    do: {unit, {from, nil}, Progress}

  def normalize_from_to(_unit, from, nil),
    do: {:time, {msecs(from), nil}, Progress}

  def normalize_from_to(unit, nil, to) when is_integer(to),
    do: {unit, {nil, to}, Progress}

  def normalize_from_to(unit, nil, to) when is_integer(to),
    do: {unit, {nil, to}, Progress}

  def normalize_from_to(_unit, nil, to),
    do: {:time, {nil, msecs(to)}, Progress}

  def normalize_from_to(_unit, from, to) do
    from = from && msecs(from)
    to = to && msecs(to)
    from || to || raise Error.Input.Scope, value: {from, to}

    case {from, to} do
      {nil, _} -> {:time, {nil, to}, Progress}
      {_, nil} -> {:time, {from, nil}, Progress}
      _ when from <= to -> {:time, {from, to}, Progress}
      _ when from > to -> {:time, {to, from}, Degress}
    end
  end

  def range(%Date{} = d) do
    from = date_time(d)
    to = DateTime.add(from, 24 * 60 * 60, :second)
    {msecs(from), msecs(to)}
  end

  def range(%DateTime{} = time) do
    msecs = msecs(time)
    {msecs, msecs}
  end

  def ordered_scope({unit, scope, order}, nil),
    do: {unit, scope, order}

  def ordered_scope({unit, scope, Progress}, Progress),
    do: {unit, scope, Progress}

  def ordered_scope({unit, scope, Degress}, Degress),
    do: {unit, scope, Degress}

  def ordered_scope({unit, {from, to}, Progress}, Degress),
    do: {unit, {to, from}, Degress}

  def ordered_scope({unit, {from, to}, Degress}, Progress),
    do: {unit, {to, from}, Progress}

  def ordered_scope({unit, single_key, _}, req_order),
    do: {unit, single_key, req_order}

  ################################################################################

  defp ordered({:range, {_, _} = x}, Progress), do: {:range, sort_tuple2(x)}
  defp ordered({:range, {_, _} = x}, Degress), do: {:range, flip_tuple(sort_tuple2(x))}
  defp ordered(x, _order), do: x

  def merge_range(nil),
    do: nil

  def merge_range({l, r}) do
    keys = fn
      {:range, {l, r}} -> [l, r]
      nil -> []
      x -> [x]
    end

    range = (keys.(l) ++ keys.(r)) |> Enum.filter(& &1)

    case range do
      [_, _ | _] -> {:range, Enum.min_max(range)}
      [x] -> {:range, {x, x}}
      [] -> nil
    end
  end

  def translate({unit, {l, r}, order}, target_unit) do
    unit = unit || target_unit
    trans = &translate1({unit, &1}, target_unit)

    case {trans.(l), trans.(r)} do
      {trans, trans} when trans != nil ->
        ordered(trans, order)

      {trans_l, trans_r} ->
        [{from, trans_l}, {to, trans_r}] = Enum.sort([{l, trans_l}, {r, trans_r}])

        ranges =
          case {trans_l, trans_r} do
            {nil, nil} ->
              align_l = align({unit, from, to}, target_unit, :left)
              align_r = align({unit, to, from}, target_unit, :right)
              align_l && align_r && {align_l, align_r}

            {nil, _} ->
              align_l = align({unit, from, to}, target_unit, :left)
              align_l && {align_l, trans_r}

            {_, nil} ->
              align_r = align({unit, to, from}, target_unit, :right)
              align_r && {trans_l, align_r}

            {_, _} ->
              {trans_l, trans_r}
          end

        ordered(merge_range(ranges), order)
    end
  end

  def translate({unit, scope, order}, target_unit) do
    unit_scope = {unit, scope}
    translation = translate1(unit_scope, target_unit)
    ordered(translation, order)
  end

  def translate({nil, val}, target_unit),
    do: translate1({target_unit, val}, target_unit)

  ##########

  def translate1({nil, i}, target_unit) when i != nil,
    do: translate1({target_unit, i}, target_unit)

  # :forward / :backward translations
  def translate1({nil, nil}, :type),
    do: {:range, {first_txi(), last_txi()}}

  def translate1({nil, nil}, :time),
    do: {:range, {first(~t[time]), last(~t[time])}}

  def translate1({nil, nil}, :txi),
    do: {:range, {first_txi(), last_txi()}}

  def translate1({nil, nil}, :gen),
    do: {:range, {first_gen(), last_gen()}}

  # bogus input check
  def translate1({:txi, i}, :txi) when is_integer(i) and i < 0,
    do: raise(ArgumentError, message: "transaction index is non-null integer, got #{inspect(i)}")

  def translate1({:time, i}, :time) when is_integer(i) and i < 0,
    do:
      raise(ArgumentError,
        message: "time (in milliseconds) is non-null integer, got #{inspect(i)}"
      )

  def translate1({:gen, i}, :gen) when is_integer(i) and i < 0,
    do: raise(ArgumentError, message: "generation is non-null integer, got #{inspect(i)}")

  # exact I unit translation
  def translate1({:txi, i}, :txi) when is_integer(i) and i >= 0,
    do: read_tx(i) |> map_one_nil(&Model.tx(&1, :index))

  def translate1({:time, i}, :time) when is_integer(i) and i >= 0,
    do: in_time_proximity(i, &id/1, @time_scope_max_diff_msecs)

  def translate1({:gen, i}, :gen) when is_integer(i) and i >= 0,
    do: read_block(i) |> map_one_nil(fn _ -> {:range, {{i, -1}, on_microblock_key(i, :last)}} end)

  # conversions
  def translate1({:txi, i}, :time) when is_integer(i) and i >= 0,
    do: read_tx(i) |> map_one_nil(fn tx -> {Model.tx(tx, :time), Model.tx(tx, :index)} end)

  def translate1({:txi, i}, :gen) when is_integer(i) and i >= 0,
    do: read_tx(i) |> map_one_nil(&Model.tx(&1, :block_index))

  def translate1({:txi, i}, :type) when is_integer(i) and i >= 0,
    do: read_tx(i) |> map_one_nil(&Model.tx(&1, :index))

  def translate1({:time, i}, :type) when is_integer(i) and i >= 0,
    do: in_time_proximity(i, fn {_, txi} -> txi end, @time_scope_max_diff_msecs)

  def translate1({:time, i}, :txi) when is_integer(i) and i >= 0,
    do: in_time_proximity(i, fn {_, txi} -> txi end, @time_scope_max_diff_msecs)

  def translate1({:time, i}, :gen) when is_integer(i) and i >= 0 do
    txi_bi = &Model.tx(read_tx!(&1), :block_index)
    in_time_proximity(i, fn {_, txi} -> txi_bi.(txi) end, @time_scope_max_diff_msecs)
  end

  def translate1({:gen, i}, :txi) when is_integer(i) and i >= 0,
    do: with_generation_range(i, on_block_txis(fn txis -> {:range, txis} end))

  def translate1({:gen, i}, :type) when is_integer(i) and i >= 0,
    do: with_generation_range(i, on_block_txis(fn txis -> {:range, txis} end))

  def translate1({:gen, i}, :time) when is_integer(i) and i >= 0,
    do:
      with_generation_range(
        i,
        on_block_txis(fn {a, b} -> {:range, {{txi_time(a), a}, {txi_time(b), b}}} end)
      )

  ##########

  def align({:gen, l, r}, :txi, :left),
    do: gen_align(l, r, :left, &first_txi/0)

  def align({:gen, l, r}, :txi, :right),
    do: gen_align(l, r, :right, &last_txi/0)

  def align({:gen, l, r}, :time, :left),
    do: gen_align(l, r, :left, &first_txi/0) |> read_tx! |> time_key

  def align({:gen, l, r}, :time, :right),
    do: gen_align(l, r, :right, &last_txi/0) |> read_tx! |> time_key

  def align({:gen, l, r}, :type, :left),
    do: gen_align(l, r, :left, &first_txi/0) |> read_tx! |> Model.tx(:index)

  def align({:gen, l, r}, :type, :right),
    do: gen_align(l, r, :right, &last_txi/0) |> read_tx! |> Model.tx(:index)

  def align({:time, l, r}, :txi, orient),
    do: time_align(l, r, orient, fn -> nil end)

  def align({:time, l, r}, :type, orient) do
    txi = time_align(l, r, orient, fn -> nil end)
    txi && Model.tx(read_tx!(txi), :index)
  end

  def align({:time, l, r}, :time, orient) do
    txi = time_align(l, r, orient, fn -> nil end)
    txi && time_key(read_tx!(txi))
  end

  # TODO: this is imprecise, only uses microblocks... (better: binary search over blocks table)
  def align({:time, l, r}, :gen, orient) do
    txi = time_align(l, r, orient, fn -> nil end)
    txi && Model.tx(read_tx!(txi), :block_index)
  end

  def align(_, :txi, :left),
    do: first_txi()

  def align(_, :txi, :right),
    do: last_txi()

  def align(_, :type, :left),
    do: Model.tx(read_tx!(first_txi()), :index)

  def align(_, :type, :right),
    do: Model.tx(read_tx!(last_txi()), :index)

  def align(_, :time, :left),
    do: map_one_nil(read_tx(first_txi()), &time_key/1)

  def align(_, :time, :right),
    do: map_one_nil(read_tx(last_txi()), &time_key/1)

  def align(_, :gen, :left),
    do: {first_gen(), -1}

  def align(_, :gen, :right),
    do: {last_gen(), -1}

  ################################################################################

  def time_range(i),
    do: Enum.min_max(List.wrap(next_time_key(i)) ++ List.wrap(prev_time_key(i)))

  def on_block_txis(f) do
    fn b1, b2 ->
      # |> prx("////////// [on_block_txis] TXI1")
      txi1 = Model.block(b1, :tx_index)
      txi2 = Model.block(b2, :tx_index)

      cond do
        is_nil(txi2) ->
          txi1 && f.({txi1, last_txi()})

        true ->
          txi2 = txi2 - 1
          txi1 = max(0, txi1)

          cond do
            txi1 > txi2 -> nil
            true -> f.(Enum.min_max([txi1, txi2]))
          end
      end
    end
  end

  def time_align(from, to, :left, default_fn) do
    case next_time_key(from) do
      {t, txi} when t <= to -> txi
      _ -> default_fn.()
    end
  end

  def time_align(from, to, :right, default_fn) do
    case prev_time_key(from) do
      {t, txi} when t >= to -> txi
      _ -> default_fn.()
    end
  end

  def gen_align(from, to, orient, default_fn) do
    case scan_microblock(from, to, orient) do
      nil -> default_fn.()
      bi -> Model.block(read_block!(bi), :tx_index) || default_fn.()
    end
  end

  def scan_microblock(h, limit_i, :left),
    do:
      collect_keys(~t[block], nil, {h, -1}, &next/2, fn
        {k, mbi}, nil when k <= limit_i ->
          (mbi >= 0 && {:halt, {k, mbi}}) || {:cont, nil}

        {_, _}, nil ->
          {:halt, nil}
      end)

  def scan_microblock(h, limit_i, :right),
    do:
      collect_keys(~t[block], nil, {h + 1, -1}, &prev/2, fn
        {k, mbi}, nil when k >= limit_i ->
          (mbi >= 0 && {:halt, {k, mbi}}) || {:cont, nil}

        {_, _}, nil ->
          {:halt, nil}
      end)

  def with_generation_range(i, f) do
    with [b1] <- read_block(i),
         true <- is_integer(Model.block(b1, :tx_index)) do
      case read_block(i + 1) do
        [b2] -> f.(b1, b2)
        [] -> f.(b1, nil)
      end
    else
      _ -> nil
    end
  end

  def time_key(tx),
    do: {Model.tx(tx, :time), Model.tx(tx, :index)}

  def next_time_key(t) do
    n = next(~t[time], {t, -1})
    (n != :"$end_of_table" && n) || nil
  end

  def prev_time_key(t) do
    p = prev(~t[time], {t, <<>>})
    (p != :"$end_of_table" && p) || nil
  end

  def on_microblock_key(g, :first),
    do: next(~t[block], {g, -1})

  def on_microblock_key(g, :last),
    do: prev(~t[block], {g, <<>>})

  def txi_type(txi) when is_integer(txi),
    do: map_one_nil(read_tx(txi), &txi_type/1)

  def txi_type(tx),
    do: Model.tx_to_raw_map(tx).tx.type

  def txi_time(txi) when is_integer(txi),
    do: map_one_nil(read_tx(txi), &Model.tx(&1, :time))

  def in_time_proximity(utc_msec, f, max_diff_msec) do
    around? = &(abs(utc_msec - elem(&1, 0)) <= max_diff_msec)
    from_l = next_time_key(utc_msec)
    from_l = (from_l && around?.(from_l) && from_l) || nil
    from_r = prev_time_key(utc_msec)
    from_r = (from_r && around?.(from_r) && from_r) || nil

    case {from_l, from_r} do
      {nil, nil} ->
        nil

      {x, x} ->
        f.(x)

      _ ->
        {:range,
         sort_tuple2(
           case {from_l, from_r} do
             {_, nil} ->
               from_l = f.(from_l)
               {from_l, from_l}

             {nil, _} ->
               from_r = f.(from_r)
               {from_r, from_r}

             {_, _} ->
               {f.(from_l), f.(from_r)}
           end
         )}
    end
  end
end
