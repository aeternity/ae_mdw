defmodule AeMdw.Extract do
  @moduledoc "currently we require that AE node is compiled with debug_info"

  import AeMdw.Util

  defmodule AbsCode do
    def reduce(mod_name, {fun_name, arity}, init_acc, f) when is_atom(mod_name),
      do: reduce(ok!(AbsCode.module(mod_name)), {fun_name, arity}, init_acc, f)

    def reduce(mod_code, {fun_name, arity}, init_acc, f) when is_list(mod_code) do
      {:ok, fn_code} = AbsCode.function(mod_code, fun_name, arity)
      Enum.reduce(fn_code, init_acc, f)
    end

    def module(module) do
      with [_ | _] = path <- :code.which(module),
           {:ok, chunk} = :beam_lib.chunks(path, [:abstract_code]),
           {_, [abstract_code: {_, code}]} <- chunk,
           do: {:ok, code}
    end

    def function(mod_code, name, arity) do
      finder = fn
        {:function, _, ^name, ^arity, code} -> code
        _ -> nil
      end

      with [_ | _] = fn_code <- Enum.find_value(mod_code, finder),
           do: {:ok, fn_code}
    end

    def function_body_bin1(mod_code, fun_name, bin_arg) do
      charlist_arg = String.to_charlist(bin_arg)
      {:ok, fn_code} = AbsCode.function(mod_code, fun_name, 1)
      Enum.reduce_while(fn_code, nil,
        fn  {:clause, _,
          [{:bin, _, [{:bin_element, _, {:string, _, ^charlist_arg}, _, _}]}], [], body}, _ ->
            {:halt, body}
          _, _ ->
            {:cont, nil}
        end)
    end

    def literal_map_assocs({:map, _, assocs}),
      do: for {:map_field_assoc, _, {_, _, k}, {_, _, v}} <- assocs, do: {k, v}

    def record_fields(mod_code, name) do
      finder = fn
        {:attribute, _, :record, {^name, fields}} -> fields
        _ -> nil
      end

      with [_ | _] = rec_fields <- Enum.find_value(mod_code, finder),
           do: {:ok, rec_fields}
    end

    def field_name_type({:typed_record_field, {:record_field, _, {:atom, _, name}}, type}),
      do: {name, type}

    def field_name_type({:typed_record_field, {:record_field, _, {:atom, _, name}, _}, type}),
      do: {name, type}

    def aeser_id_type?(abs_code) do
      case abs_code do
        {:remote_type, _, [{:atom, _, :aeser_id}, {:atom, _, :id}, []]} -> true
        _ -> false
      end
    end

    def list_of_aeser_id_type?(abs_code) do
      case abs_code do
        {:type, _, :list, [{:remote_type, _, [{:atom, _, :aeser_id}, {:atom, _, :id}, []]}]} ->
          true

        _ ->
          false
      end
    end
  end

  def tx_types() do
    {:ok,
     Code.Typespec.fetch_types(:aetx)
     |> ok!
     |> Enum.find_value(nil, &tx_type_variants/1)}
  end

  defp tx_type_variants({:type, {:tx_type, {:type, _, :union, variants}, []}}),
    do: for({:atom, _, v} <- variants, do: v)

  defp tx_type_variants(_), do: nil

  def tx_mod_map(),
    do: tx_mod_map(ok!(AbsCode.module(:aetx)))

  def tx_mod_map(mod_code),
    do:
      AbsCode.reduce(mod_code, {:type_to_cb, 1}, %{}, fn {:clause, _, [{:atom, _, t}], [],
                                                          [{:atom, _, m}]},
                                                         acc ->
        Map.put(acc, t, m)
      end)

  def tx_name_map(),
    do: tx_name_map(ok!(AbsCode.module(:aetx)))

  def tx_name_map(mod_code),
    do:
      AbsCode.reduce(mod_code, {:type_to_swagger_name, 1}, %{}, fn {:clause, _, [{:atom, _, t}],
                                                                    [],
                                                                    [
                                                                      {:bin, _,
                                                                       [
                                                                         {:bin_element, _,
                                                                          {:string, _, n}, _, _}
                                                                       ]}
                                                                    ]},
                                                                   acc ->
        Map.put(acc, t, "#{n}")
      end)

  def id_prefix_type_map(),
    do: id_prefix_type_map(ok!(AbsCode.module(:aeser_api_encoder)))

  def id_prefix_type_map(mod_code),
    do:
      AbsCode.reduce(mod_code, {:pfx2type, 1}, %{}, fn {:clause, _,
                                                        [
                                                          {:bin, _,
                                                           [
                                                             {:bin_element, _, {:string, _, pfx},
                                                              _, _}
                                                           ]}
                                                        ], [], [{:atom, _, type}]},
                                                       acc ->
        Map.put(acc, "#{pfx}", type)
      end)

  def id_type_map(),
    do: id_type_map(ok!(AbsCode.module(:aeser_api_encoder)))

  def id_type_map(mod_code),
    do:
      AbsCode.reduce(mod_code, {:id2type, 1}, %{}, fn {:clause, _, [{:atom, _, id}], [],
                                                       [{:atom, _, type}]},
                                                      acc ->
        Map.put(acc, id, type)
      end)

  defp tx_record(:name_preclaim_tx), do: :ns_preclaim_tx
  defp tx_record(:name_claim_tx), do: :ns_claim_tx
  defp tx_record(:name_transfer_tx), do: :ns_transfer_tx
  defp tx_record(:name_update_tx), do: :ns_update_tx
  defp tx_record(:name_revoke_tx), do: :ns_revoke_tx
  defp tx_record(tx_type), do: tx_type

  def tx_record_info(tx_type),
    do: tx_record_info(tx_type, &AeMdw.Node.tx_mod/1)

  def tx_record_info(:channel_client_reconnect_tx, _),
    do: {[], %{}}

  def tx_record_info(tx_type, mod_mapper) do
    mod_name = mod_mapper.(tx_type)
    mod_code = AbsCode.module(mod_name) |> ok!
    rec_code = AbsCode.record_fields(mod_code, tx_record(tx_type)) |> ok!

    {rev_names, ids} =
      rec_code
      |> Stream.with_index(1)
      |> Enum.reduce(
        {[], %{}},
        fn {ast, i}, {names, ids} ->
          {name, type} = AbsCode.field_name_type(ast)
          {[name | names], (AbsCode.aeser_id_type?(type) && put_in(ids[name], i)) || ids}
        end
      )

    {Enum.reverse(rev_names), ids}
  end
end
