defmodule AeMdw.AexnTokens do
  @moduledoc """
  Context module for AEX-N tokens.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util

  import AeMdw.Util.Encoding, only: [encode_contract: 1]
  import AeMdwWeb.Helpers.AexnHelper, only: [sort_field_truncate: 1]

  require Model

  @type aexn_type() :: :aex9 | :aex141
  @type aexn_token() :: AeMdwWeb.AexnView.aexn_contract()
  @type cursor :: binary()

  @typep pagination :: Collection.direction_limit()
  @typep order_by() :: :name | :symbol
  @typep query :: %{binary() => binary()}

  @pagination_params ~w(limit cursor rev direction by scope)
  @max_sort_field_length 100

  @aexn_table Model.AexnContract
  @aexn_name_table Model.AexnContractName
  @aexn_symbol_table Model.AexnContractSymbol

  @spec fetch_contract(State.t(), {aexn_type(), Db.pubkey()}) ::
          {:ok, Model.aexn_contract()} | {:error, Error.t()}
  def fetch_contract(state, {aexn_type, contract_pk}) do
    case State.get(state, Model.AexnContract, {aexn_type, contract_pk}) do
      {:ok, m_aexn} ->
        {:ok, m_aexn}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: encode_contract(contract_pk))}
    end
  end

  @spec fetch_contracts(State.t(), pagination(), aexn_type(), query(), order_by(), cursor() | nil) ::
          {:ok, cursor() | nil, [Model.aexn_contract()], cursor() | nil}
  def fetch_contracts(state, pagination, aexn_type, query, order_by, cursor) do
    with {:ok, cursor} <- deserialize_aexn_cursor(cursor) do
      sorted_table = if order_by == :name, do: @aexn_name_table, else: @aexn_symbol_table

      {prev_record, aexn_contracts, next_record} =
        query
        |> Map.drop(@pagination_params)
        |> validate_params()
        |> Enum.into(%{prefix: ""}, &convert_param/1)
        |> build_tokens_streamer(state, aexn_type, sorted_table, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_aexn_cursor(order_by, prev_record), aexn_contracts,
       serialize_aexn_cursor(order_by, next_record)}
    end
  end

  defp build_tokens_streamer(%{exact: exact}, state, type, table, cursor) do
    scope = {
      {type, exact, <<>>},
      {type, exact, Util.max_256bit_bin()}
    }

    do_build_tokens_streamer(state, table, cursor, scope)
  end

  defp build_tokens_streamer(%{prefix: prefix}, state, type, table, cursor) do
    prefix = String.slice(prefix, 0, @max_sort_field_length)

    scope = {
      {type, prefix, <<>>},
      {type, prefix <> Util.max_name_bin(), <<>>}
    }

    do_build_tokens_streamer(state, table, cursor, scope)
  end

  defp do_build_tokens_streamer(state, table, cursor, scope) do
    fn direction ->
      state
      |> Collection.stream(table, direction, scope, cursor)
      |> Stream.map(fn {type, _order_by_field, pubkey} ->
        State.fetch!(state, @aexn_table, {type, pubkey})
      end)
    end
  end

  defp validate_params(%{"prefix" => _, "exact" => _}),
    do: raise(ErrInput.Query, value: "can't use both `prefix` and `exact` parameters")

  defp validate_params(params), do: params

  defp convert_param({"prefix", prefix}) when is_binary(prefix), do: {:prefix, prefix}

  defp convert_param({"exact", field_value}) when is_binary(field_value),
    do: {:exact, field_value}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)

  defp serialize_aexn_cursor(_order_by, nil), do: nil

  defp serialize_aexn_cursor(
         order_by,
         {Model.aexn_contract(index: {type, pubkey}, meta_info: meta_info), is_reversed?}
       ) do
    sort_field_value = if order_by == :name, do: elem(meta_info, 0), else: elem(meta_info, 1)
    cursor = {type, sort_field_truncate(sort_field_value), pubkey}
    {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}
  end

  defp deserialize_aexn_cursor(nil), do: {:ok, nil}

  defp deserialize_aexn_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         cursor_term <- :erlang.binary_to_term(cursor_bin),
         true <- is_valid_cursor_term?(cursor_term) do
      {:ok, cursor_term}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
  end

  defp is_valid_cursor_term?({type, name_symbol, pubkey})
       when type in [:aex9, :aex141] and is_binary(name_symbol) and is_binary(pubkey),
       do: true

  defp is_valid_cursor_term?(_other_term), do: false
end
