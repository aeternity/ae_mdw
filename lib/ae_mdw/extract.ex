defmodule AeMdw.Extract do
  @moduledoc """
  Extract functions and record info from node code.

  Currently we require that AE node is compiled with debug_info.
  """

  import AeMdw.Util

  defmodule AbsCode do
    @moduledoc """
    Helper for dealing with Erlang code structures.
    """

    @type code() :: term()
    @typep fname() :: atom()

    @spec reduce(module(), {fname(), non_neg_integer()}, term(), (term(), term() -> term())) ::
            term()
    def reduce(mod_name, {fun_name, arity}, init_acc, f) when is_atom(mod_name),
      do: reduce(ok!(AbsCode.module(mod_name)), {fun_name, arity}, init_acc, f)

    def reduce(mod_code, {fun_name, arity}, init_acc, f) when is_list(mod_code) do
      {:ok, fn_code} = AbsCode.function(mod_code, fun_name, arity)
      Enum.reduce(fn_code, init_acc, f)
    end

    @spec module(module()) :: {:ok, code()} | {:error, term()}
    def module(module) do
      with [_path | _rest] = path <- :code.which(module),
           {:ok, chunk} = :beam_lib.chunks(path, [:abstract_code]),
           {_module, [abstract_code: {_version, code}]} <- chunk,
           do: {:ok, code}
    end

    @spec function(code(), fname(), non_neg_integer()) :: code() | nil
    def function(mod_code, name, arity) do
      finder = fn
        {:function, _anno, ^name, ^arity, code} -> code
        _code -> nil
      end

      with [_form | _rest] = fn_code <- Enum.find_value(mod_code, finder),
           do: {:ok, fn_code}
    end

    @spec record_fields(code(), fname()) :: {:ok, [{atom(), non_neg_integer()}]}
    def record_fields(mod_code, name) do
      finder = fn
        {:attribute, _anno, :record, {^name, fields}} -> fields
        _code -> nil
      end

      with [_field | _rest] = rec_fields <- Enum.find_value(mod_code, finder),
           do: {:ok, rec_fields}
    end

    @spec field_name_type(code()) :: {atom(), atom()}
    def field_name_type(
          {:typed_record_field, {:record_field, _anno1, {:atom, _anno2, name}}, type}
        ),
        do: {name, type}

    def field_name_type(
          {:typed_record_field, {:record_field, _anno1, {:atom, _anno2, name}, _anno3}, type}
        ),
        do: {name, type}

    def field_name_type({:record_field, _anno1, {:atom, _anno2, name}}),
      do: {name, :undefined}

    @spec aeser_id_type?(code()) :: boolean()
    def aeser_id_type?(abs_code) do
      case abs_code do
        {:remote_type, _anno1, [{:atom, _anno2, :aeser_id}, {:atom, _anno3, :id}, []]} -> true
        _code -> false
      end
    end
  end

  defp tx_record(:name_preclaim_tx), do: :ns_preclaim_tx
  defp tx_record(:name_claim_tx), do: :ns_claim_tx
  defp tx_record(:name_transfer_tx), do: :ns_transfer_tx
  defp tx_record(:name_update_tx), do: :ns_update_tx
  defp tx_record(:name_revoke_tx), do: :ns_revoke_tx
  defp tx_record(tx_type), do: tx_type

  @spec tx_record_info(atom(), (atom() -> atom())) :: {[atom()], map()}
  def tx_record_info(:channel_client_reconnect_tx, _mod_mapper),
    do: {[], %{}}

  def tx_record_info(tx_type, mod_mapper) do
    mod_name = mod_mapper.(tx_type)
    mod_code = mod_name |> AbsCode.module() |> ok!
    rec_code = mod_code |> AbsCode.record_fields(tx_record(tx_type)) |> ok!

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
