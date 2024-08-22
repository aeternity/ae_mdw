defmodule AeMdw.AexnTokens do
  @moduledoc """
  Context module for AEX-N tokens.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Aex141
  alias AeMdw.Aex9
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Stats
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1]

  require Model

  @type aexn_type() :: :aex9 | :aex141
  @type aexn_token() :: AeMdwWeb.AexnView.aexn_contract()
  @type cursor :: binary()

  @typep pagination :: Collection.direction_limit()
  @typep order_by() :: :name | :symbol | :creation
  @typep query :: %{binary() => binary()}
  @typep aexn_contract() :: map()

  @max_sort_field_length 100

  @aexn_table Model.AexnContract
  @aexn_downcased_name_table Model.AexnContractDowncasedName
  @aexn_downcased_symbol_table Model.AexnContractDowncasedSymbol
  @aexn_name_table Model.AexnContractName
  @aexn_symbol_table Model.AexnContractSymbol
  @aexn_creation_table Model.AexnContractCreation
  @sorting_table %{
    name: @aexn_name_table,
    symbol: @aexn_symbol_table,
    creation: @aexn_creation_table
  }
  @downcased_sorting_table %{
    name: @aexn_downcased_name_table,
    symbol: @aexn_downcased_symbol_table
  }

  @spec fetch_contract(State.t(), aexn_type(), binary(), boolean()) ::
          {:ok, aexn_contract()} | {:error, Error.t()}
  def fetch_contract(state, aexn_type, contract_id, v3?) do
    with {:ok, contract_pk} <- Validate.id(contract_id),
         {:ok, aexn_contract} <- State.get(state, @aexn_table, {aexn_type, contract_pk}),
         {:invalid, false} <-
           {:invalid, State.exists?(state, Model.AexnInvalidContract, {aexn_type, contract_pk})} do
      {:ok, render_contract(state, aexn_contract, v3?)}
    else
      {:invalid, true} ->
        {:error, ErrInput.AexnContractInvalid.exception(value: contract_id)}

      {:error, reason} ->
        {:error, reason}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: contract_id)}
    end
  end

  @spec fetch_contracts(
          State.t(),
          pagination(),
          aexn_type(),
          query(),
          order_by(),
          cursor() | nil,
          boolean()
        ) ::
          {:ok, {cursor() | nil, [Model.aexn_contract()], cursor() | nil}} | {:error, Error.t()}
  def fetch_contracts(state, pagination, aexn_type, query, order_by, cursor, v3?) do
    with {:ok, cursor} <- deserialize_aexn_cursor(order_by, cursor),
         {:ok, params} <- validate_params(query),
         {:ok, filters} <- Util.convert_params(params, &convert_param/1) do
      paginated_aexn_contracts =
        filters
        |> build_tokens_streamer(state, aexn_type, order_by, cursor)
        |> Collection.paginate(
          pagination,
          &render_contract(state, &1, v3?),
          &serialize_aexn_cursor/1
        )

      {:ok, paginated_aexn_contracts}
    end
  end

  defp build_tokens_streamer(_filters, state, type, :creation, cursor) do
    key_boundary = {
      {type, {0, Util.max_int()}},
      {type, {Util.max_int(), Util.max_int()}}
    }

    fn direction ->
      Collection.stream(state, @aexn_creation_table, direction, key_boundary, cursor)
    end
  end

  defp build_tokens_streamer(%{exact: exact}, state, type, order_by, cursor) do
    sorting_table = Map.fetch!(@sorting_table, order_by)

    scope = {
      {type, exact, <<>>},
      {type, exact, Util.max_256bit_bin()}
    }

    fn direction ->
      Collection.stream(state, sorting_table, direction, scope, cursor)
    end
  end

  defp build_tokens_streamer(%{prefix: prefix}, state, type, order_by, cursor) do
    sorting_table = Map.fetch!(@downcased_sorting_table, order_by)

    scope = {
      {type, prefix, <<>>},
      {type, prefix <> Util.max_name_bin(), <<>>}
    }

    fn direction ->
      Collection.stream(state, sorting_table, direction, scope, cursor)
    end
  end

  defp build_tokens_streamer(_filters, state, type, table, cursor),
    do: build_tokens_streamer(%{prefix: ""}, state, type, table, cursor)

  defp validate_params(%{"prefix" => _prefix, "exact" => _exact}),
    do:
      {:error, ErrInput.Query.exception(value: "can't use both `prefix` and `exact` parameters")}

  defp validate_params(params), do: {:ok, params}

  defp convert_param({"prefix", prefix}) when is_binary(prefix) do
    prefix =
      prefix
      |> String.slice(0, @max_sort_field_length)
      |> String.downcase()

    {:ok, {:prefix, prefix}}
  end

  defp convert_param({"exact", field_value}) when is_binary(field_value),
    do: {:ok, {:exact, field_value}}

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}

  defp serialize_aexn_cursor(index) do
    index
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp deserialize_aexn_cursor(_order_by, nil), do: {:ok, nil}

  defp deserialize_aexn_cursor(:creation, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64, padding: false),
         {aexn_type, {txi, idx}} = cursor_term
         when aexn_type in ~w(aex9 aex141)a and is_integer(txi) and is_integer(idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor_term}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
  end

  defp deserialize_aexn_cursor(_order_by, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64, padding: false),
         {aexn_type, _name_symbol_creation, pubkey} = cursor_term
         when aexn_type in ~w(aex9 aex141)a and is_binary(pubkey) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor_term}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
  end

  defp render_contract(state, {aexn_type, _symbol, contract_pk}, v3?),
    do: render_contract(state, State.fetch!(state, @aexn_table, {aexn_type, contract_pk}), v3?)

  defp render_contract(state, {aexn_type, txi_idx}, v3?) do
    Model.aexn_contract_creation(contract_pk: contract_pk) =
      State.fetch!(state, @aexn_creation_table, {aexn_type, txi_idx})

    render_contract(state, State.fetch!(state, @aexn_table, {aexn_type, contract_pk}), v3?)
  end

  defp render_contract(
         state,
         Model.aexn_contract(
           index: {:aex9, contract_pk} = index,
           txi_idx: {txi, _idx},
           meta_info: {name, symbol, decimals},
           extensions: extensions
         ),
         v3?
       ) do
    initial_supply =
      case State.get(state, Model.Aex9InitialSupply, contract_pk) do
        {:ok, Model.aex9_initial_supply(amount: amount)} -> amount
        :not_found -> 0
      end

    event_supply =
      case State.get(state, Model.Aex9ContractBalance, contract_pk) do
        {:ok, Model.aex9_contract_balance(amount: amount)} -> amount
        :not_found -> 0
      end

    num_holders = Aex9.fetch_holders_count(state, contract_pk)

    response = %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_id: encode_contract(contract_pk),
      extensions: extensions,
      initial_supply: initial_supply,
      event_supply: event_supply,
      holders: num_holders,
      invalid: State.exists?(state, Model.AexnInvalidContract, index),
      logs_count: Stats.fetch_aex9_logs_count(state, contract_pk)
    }

    case v3? do
      true ->
        Map.put(response, :contract_tx_hash, Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi)))

      false ->
        Map.put(response, :contract_txi, txi)
    end
  end

  defp render_contract(
         state,
         Model.aexn_contract(
           index: {:aex141, contract_pk} = index,
           txi_idx: {txi, _idx},
           meta_info: {name, symbol, base_url, metadata_type},
           extensions: extensions
         ),
         v3?
       ) do
    Model.tx(block_index: {height, _mbi}, time: micro_time) = DbUtil.read_tx!(state, txi)

    %{
      name: name,
      symbol: symbol,
      base_url: base_url,
      contract_txi: txi,
      contract_id: encode_contract(contract_pk),
      metadata_type: metadata_type,
      extensions: extensions,
      limits: Aex141.fetch_limits(state, contract_pk, v3?),
      invalid: State.exists?(state, Model.AexnInvalidContract, index),
      creation_time: micro_time,
      block_height: height
    }
    |> maybe_put_contract_tx_hash(state, txi, v3?)
    |> Map.merge(Stats.fetch_nft_stats(state, contract_pk))
  end

  defp maybe_put_contract_tx_hash(data, state, txi, v3?) do
    if v3? do
      data
      |> Map.put(:contract_tx_hash, Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi)))
      |> Map.delete(:contract_txi)
    else
      data
    end
  end
end
