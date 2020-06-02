defmodule AeMdwWeb.Query.Planner do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Query

  import AeMdwWeb.Util
  import AeMdw.Util

  ##########

  def plan({ids, types}),
    do: plan({Enum.count(ids), ids}, {Enum.count(types), types})


  def plan({0, _}, {0, _}), do: :history
  def plan({0, _}, {_, types}), do: {:type, types}
  def plan({ids_count, ids}, {0, _}) do
    types = AE.tx_types()
    plan({ids_count, ids}, {Enum.count(types), types})
  end

  def plan({_, ids}, {_, types}) do
    [min_bounds | rem_bounds] =
      Map.values(ids) |> Enum.sort_by(fn {_, bounds} -> Enum.count(bounds) end)
    initial = initial_assignments(min_bounds, types)
    final = extend_assignments(initial, rem_bounds)
    final && Query.Optimizer.optimize(final)
  end


  def initial_assignments({pubkeys, type_bounds}, types) do
    for {type, poss} <- type_bounds, reduce: %{} do
      acc ->
        case type in types do
          true ->
            all_positions = Query.Util.tx_positions(type)
            type_variants = position_variants(type, pubkeys, poss, all_positions)
            type_variants && Map.put(acc, type, {:or, type_variants}) || acc
          false ->
            acc
        end
    end
  end

  def extend_assignments(initial, rem_bounds) do
    Enum.reduce_while(rem_bounds, initial,
      fn {pks, type_bounds}, acc ->
        type_bounds = Map.take(type_bounds, Map.keys(acc))
        case Enum.count(type_bounds) do
          0 -> {:halt, nil}
          _ ->
            acc =
              Enum.reduce_while(type_bounds, acc,
                fn {type, poss}, acc ->
                  case extend_position_variants(acc[type], type, pks) do
                    nil ->
                      {:halt, nil}
                    new_variants ->
                      {:cont, Map.put(acc, type, {:or, new_variants})}
                  end
                end)
            acc && {:cont, acc} || {:halt, nil}
        end
      end)
  end

  def extend_position_variants({:or, curr_variants}, tx_type, pubkeys) do
    Enum.reduce_while(curr_variants, [],
      fn {free_poss, assignment}, acc ->
        all_positions = Query.Util.tx_positions(tx_type)
        case position_variants(tx_type, pubkeys, free_poss, all_positions) do
          nil ->
            {:halt, nil}
          extensions ->
            {_, assignment_poss} = Enum.unzip(assignment)
            merged = for {rem_free_poss, ext} <- extensions,
              do: {rem_free_poss -- assignment_poss, assignment ++ ext}
            {:cont, acc ++ merged}
        end
      end)
  end

  def position_variants(tx_type, [_|_] = pubkeys, [_|_] = positions, all_positions) do
    num_pubkeys = Enum.count(pubkeys)
    num_positions = Enum.count(positions)
    cond do
      num_pubkeys > num_positions ->
        nil
      num_pubkeys == num_positions ->
        pos_perms = permutations(positions)
        pks_combs = combinations(pubkeys, num_positions)
        Enum.flat_map(pks_combs,
          fn pks -> Enum.map(pos_perms, &{all_positions -- &1, Enum.zip(pks, &1)}) end)
      num_pubkeys < num_positions ->
        pks_perms = permutations(pubkeys)
        pos_combs = combinations(positions, num_pubkeys)
        Enum.flat_map(pos_combs,
          fn pos -> Enum.map(pks_perms, &{all_positions -- pos, Enum.zip(&1, pos)}) end)
    end
  end

  ##########


  def t1() do
    "spend.sender_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&recipient_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&type_group=channel"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t2() do
    "account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t3() do
    "sender_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t4() do
    "contract_id=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t5() do
    "account=ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t6() do
    "account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t7() do
    "account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t8() do
    "account=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&account=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t9() do
    "name_transfer.recipient_id=ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF&account=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t10() do
    "sender_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t11() do
    "account=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&account=ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS&account=ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

  def t12() do
    "account=ak_HzcS4HvhTtiD3KaVXW9umgqCW6dyg3KWgmyxHfir8x9Rads4a&contract=ct_2rtXsV55jftV36BMeR5gtakN2VjcPtZa3PBURvzShSYWEht3Z7&"
    |> AeMdwWeb.Query.Parser.parse
    |> plan
  end

end
