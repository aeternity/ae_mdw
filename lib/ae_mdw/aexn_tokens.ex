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
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1]
  import AeMdwWeb.Helpers.AexnHelper, only: [sort_field_truncate: 1]

  require Model

  @type aexn_type() :: :aex9 | :aex141
  @type aexn_token() :: AeMdwWeb.AexnView.aexn_contract()
  @type cursor :: binary()

  @typep pagination :: Collection.direction_limit()
  @typep order_by() :: :name | :symbol | :creation
  @typep query :: %{binary() => binary()}

  @max_sort_field_length 100

  @aexn_table Model.AexnContract
  @aexn_name_table Model.AexnContractName
  @aexn_symbol_table Model.AexnContractSymbol
  @aexn_creation_table Model.AexnContractCreation
  @sorting_table %{
    name: @aexn_name_table,
    symbol: @aexn_symbol_table,
    creation: @aexn_creation_table
  }

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
          {:ok, {cursor() | nil, [Model.aexn_contract()], cursor() | nil}} | {:error, Error.t()}
  def fetch_contracts(state, pagination, aexn_type, query, order_by, cursor) do
    with {:ok, cursor} <- deserialize_aexn_cursor(cursor),
         {:ok, params} <- validate_params(query),
         {:ok, filters} <- Util.convert_params(params, &convert_param/1) do
      sorting_table = Map.fetch!(@sorting_table, order_by)

      paginated_aexn_contracts =
        filters
        |> build_tokens_streamer(state, aexn_type, sorting_table, cursor)
        |> Collection.paginate(pagination, & &1, &serialize_aexn_cursor(order_by, &1))

      {:ok, paginated_aexn_contracts}
    end
  end

  defp build_tokens_streamer(_filters, state, type, @aexn_creation_table, cursor) do
    key_boundary = {
      {type, {0, Util.max_int()}},
      {type, {Util.max_int(), Util.max_int()}}
    }

    fn direction ->
      state
      |> Collection.stream(@aexn_creation_table, direction, key_boundary, cursor)
      |> Stream.map(fn {aexn_type, txi_idx} ->
        Model.aexn_contract_creation(contract_pk: pubkey) =
          State.fetch!(state, @aexn_creation_table, {aexn_type, txi_idx})

        State.fetch!(state, @aexn_table, {aexn_type, pubkey})
      end)
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

  defp build_tokens_streamer(_filters, state, type, table, cursor),
    do: build_tokens_streamer(%{prefix: ""}, state, type, table, cursor)

  defp do_build_tokens_streamer(state, table, cursor, scope) do
    fn direction ->
      state
      |> Collection.stream(table, direction, scope, cursor)
      |> Stream.map(fn {type, _order_by_field, pubkey} ->
        State.fetch!(state, @aexn_table, {type, pubkey})
      end)
    end
  end

  defp validate_params(%{"prefix" => _prefix, "exact" => _exact}),
    do:
      {:error, ErrInput.Query.exception(value: "can't use both `prefix` and `exact` parameters")}

  defp validate_params(params), do: {:ok, params}

  defp convert_param({"prefix", prefix}) when is_binary(prefix), do: {:ok, {:prefix, prefix}}

  defp convert_param({"exact", field_value}) when is_binary(field_value),
    do: {:ok, {:exact, field_value}}

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}

  defp serialize_aexn_cursor(
         :creation,
         Model.aexn_contract(index: {type, _pubkey}, txi_idx: txi_idx)
       ) do
    {type, txi_idx}
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp serialize_aexn_cursor(
         order_by,
         Model.aexn_contract(index: {type, pubkey}, meta_info: meta_info)
       ) do
    sort_field_value = if order_by == :name, do: elem(meta_info, 0), else: elem(meta_info, 1)

    {type, sort_field_truncate(sort_field_value), pubkey}
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp deserialize_aexn_cursor(nil), do: {:ok, nil}

  defp deserialize_aexn_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64, padding: false),
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

  defp is_valid_cursor_term?({type, name_symbol_creation, pubkey})
       when type in [:aex9, :aex141] and is_binary(name_symbol_creation) do
    match?({:ok, _pk}, Validate.id(pubkey, [:contract_pubkey]))
  end

  defp is_valid_cursor_term?({type, {txi, idx}}) when type in [:aex9, :aex141] do
    txi > 0 and idx >= -1
  end

  defp is_valid_cursor_term?(_other_term), do: false
end
