defmodule AeMdw.Dex do
  @moduledoc """
  Search for DEX swaps.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Util.Encoding
  alias AeMdw.Collection
  alias AeMdw.Contracts
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util
  alias AeMdw.Validate
  alias AeMdw.Sync.DexCache
  alias AeMdw.Txs

  require Model

  @account_swaps_table Model.DexAccountSwapTokens
  @contract_swaps_table Model.DexContractSwapTokens
  @swaps_table Model.DexSwapTokens

  @ae_token_contract_pks Application.compile_env(:ae_mdw, :ae_token)

  @typep encoded_pubkey() :: Encoding.encoded_hash()
  @typep amount() :: non_neg_integer()
  @typep swap() :: %{
           caller: encoded_pubkey(),
           to_account: encoded_pubkey(),
           from_token: binary(),
           to_token: binary(),
           tx_hash: binary(),
           log_idx: Contracts.log_idx(),
           amounts: [amount()]
         }
  @typep paginated_swaps() :: {page_cursor(), [swap()], page_cursor()}
  @typep cursor :: binary()
  @typep pagination :: Collection.direction_limit()
  @typep page_cursor :: Collection.pagination_cursor()
  @typep query() :: map()
  @typep range :: {:gen, Range.t()} | nil

  @spec fetch_account_swaps(State.t(), binary(), pagination(), range(), cursor(), query()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_account_swaps(state, account_id, pagination, scope, cursor, query) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, cursor} <- deserialize_account_swaps_cursor(cursor),
         {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      state
      |> build_account_swaps_streamer(account_pk, filters, scope, cursor)
      |> Collection.paginate(pagination, &render_swap(state, &1), &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_contract_swaps(State.t(), String.t(), pagination(), range(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_contract_swaps(state, contract_id, pagination, scope, cursor) do
    with {:ok, searched_contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, contract_pks} <- DexCache.get_pair_contract_pk(searched_contract_pk),
         {:ok, create_txis} <-
           Enum.reduce_while(contract_pks, {:ok, []}, fn contract_pk, {:ok, create_txis} ->
             case Origin.tx_index(state, {:contract, contract_pk}) do
               {:ok, create_txi} -> {:cont, {:ok, [create_txi | create_txis]}}
               :not_found -> {:halt, :not_found}
             end
           end),
         {:ok, cursor} <- deserialize_contract_swaps_cursor(cursor) do
      state
      |> build_contract_swaps_streamer(create_txis, scope, cursor)
      |> Collection.paginate(pagination, &render_swap(state, &1), &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    else
      :not_found -> {:error, ErrInput.NotAex9.exception(value: contract_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_swaps(State.t(), pagination(), range(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_swaps(state, pagination, scope, cursor) do
    with {:ok, cursor} <- deserialize_account_swaps_cursor(cursor) do
      state
      |> build_swaps_streamer(scope, cursor)
      |> Collection.paginate(pagination, &render_swap(state, &1), &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  @spec get_create_txi(State.t(), Txs.txi(), Txs.txi(), Contracts.log_idx()) :: Txs.txi()
  def get_create_txi(state, create_txi, txi, log_idx) do
    Model.contract_log(ext_contract: ext_contract) =
      State.fetch!(state, Model.ContractLog, {create_txi, txi, log_idx})

    case ext_contract do
      {:parent_contract_pk, contract_pk} ->
        create_txi = Origin.tx_index!(state, {:contract, contract_pk})

        case State.fetch!(state, Model.ContractLog, {create_txi, txi, log_idx}) do
          Model.contract_log(ext_contract: nil) ->
            create_txi

          Model.contract_log(ext_contract: contract_pk) ->
            Origin.tx_index!(state, {:contract, contract_pk})
        end

      nil ->
        create_txi

      contract_pk ->
        Origin.tx_index!(state, {:contract, contract_pk})
    end
  end

  defp build_account_swaps_streamer(state, account_pk, %{create_txi: create_txi}, scope, cursor) do
    key_boundary =
      if scope do
        first_txi..last_txi//_ = gen_range_to_txi(state, scope)

        {
          {account_pk, create_txi, first_txi, nil},
          {account_pk, create_txi, last_txi, nil}
        }
      else
        {
          {account_pk, create_txi, Util.min_int(), nil},
          {account_pk, create_txi, Util.max_int(), nil}
        }
      end

    fn direction ->
      Collection.stream(state, @account_swaps_table, direction, key_boundary, cursor)
    end
  end

  defp build_account_swaps_streamer(state, account_pk, _query, scope, cursor) do
    key_boundary =
      if scope do
        first_txi..last_txi//_ = gen_range_to_txi(state, scope)

        {
          {account_pk, first_txi, nil, nil},
          {account_pk, last_txi, nil, nil}
        }
      else
        {
          {account_pk, Util.min_int(), nil, nil},
          {account_pk, Util.max_int(), nil, nil}
        }
      end

    cursor =
      case cursor do
        nil -> nil
        {_account_pk, create_txi, txi, log_idx} -> {account_pk, create_txi, txi, log_idx}
      end

    fn direction ->
      Collection.stream(state, @account_swaps_table, direction, key_boundary, cursor)
    end
  end

  defp build_swaps_streamer(state, scope, cursor) do
    key_boundary =
      if scope do
        first_txi..last_txi//_ = gen_range_to_txi(state, scope)

        {
          {first_txi, Util.min_int(), nil},
          {last_txi, Util.max_int(), nil}
        }
      end

    cursor =
      case cursor do
        nil -> nil
        {_account_pk, create_txi, txi, log_idx} -> {txi, log_idx, create_txi}
      end

    fn direction ->
      state
      |> Collection.stream(@swaps_table, direction, key_boundary, cursor)
      |> Stream.map(fn {txi, log_idx, create_txi} ->
        index = {create_txi, txi, log_idx}
        Model.contract_log(args: [from, _to]) = State.fetch!(state, Model.ContractLog, index)

        {from, create_txi, txi, log_idx}
      end)
    end
  end

  defp build_contract_swaps_streamer(state, create_txis, _scope, cursor) do
    fn direction ->
      create_txis
      |> Enum.map(fn create_txi ->
        cursor =
          case cursor do
            {account_pk, txi, log_idx} -> {create_txi, account_pk, txi, log_idx}
            nil -> nil
          end

        key_boundary = {
          {create_txi, Util.min_bin(), nil, nil},
          {create_txi, Util.max_256bit_bin(), nil, nil}
        }

        Collection.stream(state, @contract_swaps_table, direction, key_boundary, cursor)
      end)
      |> Collection.merge(direction)
    end
  end

  defp deserialize_account_swaps_cursor(nil), do: {:ok, nil}

  defp deserialize_account_swaps_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {<<_pk::256>>, create_txi, txi, log_idx} = cursor
         when is_integer(create_txi) and is_integer(txi) and is_integer(log_idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  end

  defp deserialize_contract_swaps_cursor(nil), do: {:ok, nil}

  defp deserialize_contract_swaps_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {create_txi, <<_pk::256>> = account_pk, txi, log_idx}
         when is_integer(create_txi) and is_integer(txi) and is_integer(log_idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {account_pk, txi, log_idx}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  end

  defp serialize_cursor(cursor_tuple) do
    cursor_tuple
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end

  defp render_swap(state, {create_txi, <<_pk::256>> = caller_pk, txi, log_idx}),
    do: render_swap(state, {caller_pk, create_txi, txi, log_idx})

  defp render_swap(state, {<<_pk::256>> = caller_pk, create_txi, txi, log_idx}) do
    Model.dex_account_swap_tokens(to: to_pk, amounts: amounts) =
      State.fetch!(state, Model.DexAccountSwapTokens, {caller_pk, create_txi, txi, log_idx})

    create_txi = get_create_txi(state, create_txi, txi, log_idx)

    Model.tx(id: _tx_hash, block_index: {height, _mbi} = block_index, time: time) =
      State.fetch!(state, Model.Tx, create_txi)

    Model.block(hash: hash) = State.fetch!(state, Model.Block, block_index)
    contract_pk = Origin.pubkey!(state, {:contract, create_txi})
    %{token1: token1_pk, token2: token2_pk} = DexCache.get_pair(contract_pk)

    {:ok, {_name, _symbol, from_decimals}} = AexnContracts.call_meta_info(:aex9, token1_pk, hash)
    {:ok, {_name, _symbol, to_decimals}} = AexnContracts.call_meta_info(:aex9, token2_pk, hash)

    %{token1: token1_symbol, token2: token2_symbol} = DexCache.get_pair_symbols(create_txi)

    %{token1: token1_pk, token2: token2_pk} = DexCache.get_pair(contract_pk)

    %{
      amount0_in: amount0_in,
      amount1_in: amount1_in,
      amount0_out: amount0_out,
      amount1_out: amount1_out
    } = rendered_amounts = render_amounts(amounts)

    %{
      action: action(token1_pk, token2_pk),
      caller: Encoding.encode(:account_pubkey, caller_pk),
      to_account: Encoding.encode(:account_pubkey, to_pk),
      from_contract: Encoding.encode_contract(token1_pk),
      to_contract: Encoding.encode_contract(token2_pk),
      from_token: token1_symbol,
      to_token: token2_symbol,
      from_amount: amount0_in + amount1_in,
      to_amount: amount0_out + amount1_out,
      from_decimals: from_decimals,
      to_decimals: to_decimals,
      tx_hash: Encoding.encode(:tx_hash, Txs.txi_to_hash(state, txi)),
      log_idx: log_idx,
      amounts: rendered_amounts,
      micro_time: time,
      height: height
    }
  end

  defp action(t1, t2) do
    ae_token = Map.get(@ae_token_contract_pks, :aec_governance.get_network_id())

    case {t1, t2} do
      {^ae_token, _t2} -> "BUY"
      {_t1, ^ae_token} -> "SELL"
      {_t1, _t2} -> "SWAP"
    end
  end

  defp convert_param({"token_symbol", token_symbol}) when is_binary(token_symbol) do
    case DexCache.get_token_pair_txi(token_symbol) do
      :not_found -> {:error, ErrInput.NotAex9.exception(value: token_symbol)}
      {:ok, create_txi} -> {:ok, {:create_txi, create_txi}}
    end
  end

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}

  @spec render_amounts(list(integer())) :: %{
          amount0_in: integer(),
          amount1_in: integer(),
          amount0_out: integer(),
          amount1_out: integer()
        }
  defp render_amounts([amount0_in, amount1_in, amount0_out, amount1_out]) do
    %{
      amount0_in: amount0_in,
      amount1_in: amount1_in,
      amount0_out: amount0_out,
      amount1_out: amount1_out
    }
  end

  defp render_amounts(_amounts) do
    "invalid amounts"
  end

  defp gen_range_to_txi(state, {:gen, first_gen..last_gen//_}) do
    first_txi = DbUtil.first_gen_to_txi(state, first_gen)
    last_txi = DbUtil.last_gen_to_txi(state, last_gen)

    first_txi..last_txi
  end
end
