defmodule AeMdwWeb.Query.Optimizer do
  alias AeMdw.Db.Model
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Query.Util, as: QUtil

  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  ##########

  def optimize(assignments) do
    roots_checks = Enum.reduce(assignments, %{}, &add_roots_checks/2)
    for {{type, pos, pk} = root, {:or, root_checks}} <- roots_checks, reduce: {[], %{}} do
      {roots, checks} ->
        {[root | roots],
         case root_checks do
           [{:and, []}] ->
             checks
           [{:and, [_ | _] = root_checks}] ->
             root_checks = {{pk, pos}, root_checks}
             Map.update(checks, type, [root_checks], fn xs -> [root_checks | xs] end)
         end}
    end
    |> case do
         {[], %{}} -> nil
         res -> res
       end
  end

  def add_roots_checks({tx_type, {:or, pos_variants}}, root_groups) do
    Enum.reduce(pos_variants, root_groups,
      fn {_, variant}, root_groups ->
        case sort_variant(tx_type, variant) do
          nil ->
            root_groups
          [{pubkey, pos} | checks] ->
            root = {tx_type, pos, pubkey}
            Map.update(root_groups, root, {:or, [{:and, checks}]},
              fn {:or, all_root_checks} ->
                {:or,
                 case Enum.find(all_root_checks, &(&1 === {:and, checks})) do
                   nil ->
                     [{:and, checks} | all_root_checks]
                   _ ->
                     all_root_checks
                 end}
              end)
        end
      end)
  end

  def sort_variant(tx_type, [_|_] = variant) do
    sorted =
      Enum.reduce_while(variant, :gb_sets.new(),
        fn bound, acc ->
          case bound_count(tx_type, bound) do
            0 -> {:halt, nil}
            c -> {:cont, :gb_sets.add({c, bound}, acc)}
          end
        end)
    case sorted do
      nil -> nil
      set ->
        {_, elts} = Enum.unzip(:gb_sets.to_list(set))
        elts
    end
  end

  def bound_count(tx_type, {pubkey, pos}) do
    case read(Model.IdCount, {tx_type, pos, pubkey}) do
      [] ->
        0
      [rec] ->
        Model.id_count(rec, :count)
    end
  end

end
