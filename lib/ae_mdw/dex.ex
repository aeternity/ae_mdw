defmodule AeMdw.Dex do
  @moduledoc """
  Search for DEX swaps.
  """

  alias AeMdw.Util.Encoding
  alias AeMdw.Collection
  alias AeMdw.Contracts
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate
  alias AeMdw.Txs

  require Model

  @account_swaps_table Model.DexAccountSwapTokens
  @contract_swaps_table Model.DexContractSwapTokens
  @contract_debug_swaps_table Model.DexContractTokenSwap
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
  @typep pubkey() :: Db.pubkey()

  @spec fetch_account_swaps(State.t(), binary(), pagination(), range(), cursor(), query()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_account_swaps(state, account_id, pagination, scope, cursor, query) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, cursor} <- deserialize_account_swaps_cursor(cursor),
         {:ok, filters} <- Util.convert_params(query, &convert_param(state, &1)) do
      state
      |> build_account_swaps_streamer(account_pk, filters, scope, cursor)
      |> Collection.paginate(pagination, &render_swap(state, &1), &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  @spec fetch_contract_swaps(State.t(), String.t(), pagination(), range(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_contract_swaps(state, contract_id, pagination, _scope, cursor) do
    with {:ok, token_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, create_txis} <- get_pair_create_txis(state, token_pk),
         {:ok, cursor} <- deserialize_contract_swaps_cursor(cursor) do
      state
      |> build_contract_swaps_streamer(create_txis, cursor)
      |> Collection.paginate(pagination, &render_swap(state, &1), &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    else
      :not_found -> {:error, ErrInput.NotAex9.exception(value: contract_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_debug_contract_swaps(State.t(), String.t(), pagination(), range(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_debug_contract_swaps(state, contract_id, pagination, _scope, cursor) do
    with {:ok, token_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, cursor} <- deserialize_debug_contract_swaps_cursor(cursor),
         {:ok, create_txi_idx} <- Origin.creation_txi_idx(state, token_pk) do
      state
      |> build_debug_contract_swaps_streamer(create_txi_idx, cursor)
      |> Collection.paginate(pagination, &render_debug_swap(state, &1), &serialize_cursor/1)
      |> then(&{:ok, &1})
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

  @spec get_pair_pk(State.t(), Txs.txi(), Txs.txi(), Contracts.log_idx()) :: pubkey()
  def get_pair_pk(state, create_txi, txi, log_idx) do
    Model.contract_log(ext_contract: ext_contract) =
      State.fetch!(state, Model.ContractLog, {create_txi, txi, log_idx})

    case ext_contract do
      {:parent_contract_pk, contract_pk} ->
        create_txi = Origin.tx_index!(state, {:contract, contract_pk})

        case State.fetch!(state, Model.ContractLog, {create_txi, txi, log_idx}) do
          Model.contract_log(ext_contract: nil) ->
            contract_pk

          Model.contract_log(ext_contract: contract_pk) ->
            contract_pk
        end

      nil ->
        Origin.pubkey!(state, {:contract, create_txi})

      contract_pk ->
        contract_pk
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

  defp build_account_swaps_streamer(
         state,
         account_pk,
         %{pair_create_txi_idx: {pair_create_txi, _idx}},
         scope,
         cursor
       ) do
    key_boundary =
      if scope do
        first_txi..last_txi//_step = gen_range_to_txi(state, scope)

        {
          {account_pk, pair_create_txi, first_txi, nil},
          {account_pk, pair_create_txi, last_txi, nil}
        }
      else
        {
          {account_pk, pair_create_txi, Util.min_int(), nil},
          {account_pk, pair_create_txi, Util.max_int(), nil}
        }
      end

    fn direction ->
      Collection.stream(state, @account_swaps_table, direction, key_boundary, cursor)
    end
  end

  defp build_account_swaps_streamer(state, account_pk, _query, scope, cursor) do
    key_boundary =
      if scope do
        first_txi..last_txi//_step = gen_range_to_txi(state, scope)

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
        first_txi..last_txi//_step = gen_range_to_txi(state, scope)

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

  defp build_contract_swaps_streamer(state, create_txis, cursor) do
    fn direction ->
      create_txis
      |> Enum.map(fn create_txi ->
        cursor =
          case cursor do
            {account_pk, txi, log_idx} -> {create_txi, account_pk, txi, log_idx}
            nil -> nil
          end

        key_boundary =
          Collection.generate_key_boundary(
            {create_txi, Collection.binary(), Collection.integer(), Collection.integer()}
          )

        Collection.stream(state, @contract_swaps_table, direction, key_boundary, cursor)
      end)
      |> Collection.merge(direction)
    end
  end

  defp build_debug_contract_swaps_streamer(state, create_txi_idx, cursor) do
    fn direction ->
      cursor =
        case cursor do
          {_create_txi_idx, txi, log_idx} -> {create_txi_idx, txi, log_idx}
          nil -> nil
        end

      key_boundary =
        Collection.generate_key_boundary(
          {create_txi_idx, Collection.integer(), Collection.integer()}
        )

      Collection.stream(state, @contract_debug_swaps_table, direction, key_boundary, cursor)
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

  defp deserialize_debug_contract_swaps_cursor(nil), do: {:ok, nil}

  defp deserialize_debug_contract_swaps_cursor(cursor_bin) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_bin, padding: false),
         {{create_txi, create_idx}, txi, log_idx}
         when is_integer(create_txi) and is_integer(create_idx) and is_integer(txi) and
                is_integer(log_idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {{create_txi, create_idx}, txi, log_idx}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp serialize_cursor(cursor_tuple) do
    cursor_tuple
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end

  defp render_debug_swap(state, {_create_txi_idx, txi, log_idx} = index) do
    Model.dex_contract_token_swap(contract_call_create_txi: contract_call_create_txi) =
      State.fetch!(state, Model.DexContractTokenSwap, index)

    Model.contract_log(args: [from, _to]) =
      State.fetch!(state, Model.ContractLog, {contract_call_create_txi, txi, log_idx})

    render_swap(state, {contract_call_create_txi, from, txi, log_idx})
  end

  defp render_swap(state, {create_txi, <<_pk::256>> = caller_pk, txi, log_idx}),
    do: render_swap(state, {caller_pk, create_txi, txi, log_idx})

  defp render_swap(state, {<<_pk::256>> = caller_pk, create_txi, txi, log_idx}) do
    Model.dex_account_swap_tokens(to: to_pk, amounts: amounts) =
      State.fetch!(state, Model.DexAccountSwapTokens, {caller_pk, create_txi, txi, log_idx})

    create_txi = get_create_txi(state, create_txi, txi, log_idx)

    Model.tx(id: _tx_hash, block_index: {height, _mbi}, time: time) =
      State.fetch!(state, Model.Tx, create_txi)

    pair_pk = Origin.pubkey!(state, {:contract, create_txi})

    Model.dex_pair(token1_pk: token1_pk, token2_pk: token2_pk) =
      State.fetch!(state, Model.DexPair, pair_pk)

    Model.aexn_contract(meta_info: {_name, token1_symbol, from_decimals}) =
      State.fetch!(state, Model.AexnContract, {:aex9, token1_pk})

    Model.aexn_contract(meta_info: {_name, token2_symbol, to_decimals}) =
      State.fetch!(state, Model.AexnContract, {:aex9, token2_pk})

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

  defp convert_param(state, {"token_symbol", token_symbol}) when is_binary(token_symbol) do
    case State.get(state, Model.DexTokenSymbol, token_symbol) do
      :not_found ->
        {:error, ErrInput.NotAex9.exception(value: token_symbol)}

      {:ok, Model.dex_token_symbol(pair_create_txi_idx: pair_create_txi_idx)} ->
        {:ok, {:pair_create_txi_idx, pair_create_txi_idx}}
    end
  end

  defp convert_param(_state, other_param),
    do: {:error, ErrInput.Query.exception(value: other_param)}

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

  defp gen_range_to_txi(state, {:gen, first_gen..last_gen//_step}) do
    first_txi = DbUtil.first_gen_to_txi(state, first_gen)
    last_txi = DbUtil.last_gen_to_txi(state, last_gen)

    first_txi..last_txi
  end

  defp get_pair_create_txis(state, token_pk) do
    state
    |> Collection.stream(Model.DexPair, nil)
    |> Stream.map(&State.fetch!(state, Model.DexPair, &1))
    |> Stream.filter(fn Model.dex_pair(index: pair_pk, token1_pk: token1_pk, token2_pk: token2_pk) ->
      token_pk in [pair_pk, token1_pk, token2_pk]
    end)
    |> Stream.map(fn Model.dex_pair(index: pair_pk) ->
      pair_pk
    end)
    |> Enum.reduce([], fn pair_pk, create_txis ->
      case Origin.tx_index(state, {:contract, pair_pk}) do
        {:ok, create_txi} -> [create_txi | create_txis]
        :not_found -> create_txis
      end
    end)
    |> then(&{:ok, &1})
  end
end
