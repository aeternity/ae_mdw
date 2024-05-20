defmodule AeMdw.Dex do
  @moduledoc """
  Search for DEX swaps.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util
  alias AeMdw.Validate
  alias AeMdw.Sync.DexCache
  alias AeMdw.Txs

  require Model

  @account_swaps_table Model.DexAccountSwapTokens
  @contract_swaps_table Model.DexContractSwapTokens
  @dex_swap_tokens_table Model.DexSwapTokens

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @typep paginated_account_swaps ::
           {page_cursor(), [Model.dex_account_swap_tokens_index()], page_cursor()}

  @typep paginated_contract_swaps ::
           {page_cursor(), [Model.dex_contract_swap_tokens_index()], page_cursor()}

  @typep account_query :: pubkey() | {pubkey(), integer()}
  @typep cursor :: binary()
  @typep pagination :: Collection.direction_limit()
  @typep page_cursor :: Collection.pagination_cursor()
  @typep txi() :: Txs.txi()

  @spec fetch_swaps_for_account(State.t(), {String.t(), String.t()}, pagination(), cursor()) ::
          {:ok, paginated_account_swaps()} | {:error, Error.t()}
  def fetch_swaps_for_account(state, {account_id, token_symbol}, pagination, cursor) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, create_txi} <- validate_token(token_symbol) do
      fetch_account_swaps(state, {account_pk, create_txi}, pagination, cursor)
    end
  end

  @spec fetch_swaps_for_account(State.t(), String.t(), pagination(), cursor()) ::
          {:ok, paginated_account_swaps()} | {:error, Error.t()}
  def fetch_swaps_for_account(state, account_id, pagination, cursor) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      fetch_account_swaps(state, account_pk, pagination, cursor)
    end
  end

  @spec fetch_swaps_by_token_symbol(State.t(), String.t(), pagination(), cursor()) ::
          {:ok, paginated_contract_swaps()} | {:error, Error.t()}
  def fetch_swaps_by_token_symbol(state, token_symbol, pagination, cursor) do
    with {:ok, create_txi} <- validate_token(token_symbol) do
      fetch_contract_swaps(state, create_txi, pagination, cursor)
    end
  end

  @spec fetch_swaps_by_contract_id(State.t(), String.t(), pagination(), cursor()) ::
          {:ok, paginated_contract_swaps()} | {:error, Error.t()}
  def fetch_swaps_by_contract_id(state, contract_id, pagination, cursor) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, create_txi} <- Origin.tx_index(state, {:contract, contract_pk}),
         {:ok, swaps} <- fetch_swaps(state, create_txi, pagination, cursor) do
      {:ok, swaps}
    else
      :not_found -> {:error, ErrInput.NotAex9.exception(value: contract_id)}
      err -> err
    end
  end

  def fetch_swaps(state, create_txi, pagination, cursor) do
    with {:ok, cursor} <- deserialize_dex_swaps_cursor(cursor) do
      state
      |> build_streamer(
        @dex_swap_tokens_table,
        key_boundary(@dex_swap_tokens_table, create_txi),
        cursor
      )
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    end
  end

  @spec validate_token(String.t()) :: {:ok, pos_integer()} | {:error, Error.t()}
  def validate_token(token_symbol) do
    case DexCache.get_token_pair_txi(token_symbol) do
      nil -> {:error, ErrInput.NotAex9.exception(value: token_symbol)}
      create_txi -> {:ok, create_txi}
    end
  end

  @spec fetch_account_swaps(State.t(), account_query(), pagination(), cursor()) ::
          {:ok, paginated_account_swaps()} | {:error, Error.t()}
  defp fetch_account_swaps(state, query, pagination, cursor) do
    with {:ok, cursor} <- deserialize_account_cursor(cursor) do
      state
      |> build_streamer(@account_swaps_table, key_boundary(query), cursor)
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    end
  end

  @spec fetch_contract_swaps(State.t(), txi(), pagination(), cursor()) ::
          {:ok, paginated_contract_swaps()} | {:error, Error.t()}
  defp fetch_contract_swaps(state, create_txi, pagination, cursor) do
    with {:ok, cursor} <- deserialize_contract_cursor(cursor) do
      state
      |> build_streamer(@contract_swaps_table, key_boundary(create_txi), cursor)
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    end
  end

  defp build_streamer(state, @account_swaps_table = table, boundary, cursor) do
    fn direction ->
      Collection.stream(state, table, direction, boundary, cursor)
    end
  end

  defp build_streamer(state, @contract_swaps_table = table, boundary, cursor) do
    fn direction ->
      state
      |> Collection.stream(table, direction, boundary, cursor)
      |> Stream.map(fn {create_txi, account_pk, txi, log_idx} ->
        {account_pk, create_txi, txi, log_idx}
      end)
    end
  end

  defp build_streamer(state, @dex_swap_tokens_table = table, boundary, cursor) do
    fn direction ->
      state
      |> Collection.stream(table, direction, boundary, cursor)
      |> Stream.map(fn {create_txi, txi, log_idx} = index ->
        Model.contract_log(args: [from, _to]) = State.fetch!(state, Model.ContractLog, index)

        {from, create_txi, txi, log_idx}
      end)
    end
  end

  defp deserialize_account_cursor(nil), do: {:ok, nil}

  defp deserialize_account_cursor(cursor_hex) do
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

  defp deserialize_contract_cursor(nil), do: {:ok, nil}

  defp deserialize_contract_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {<<_pk::256>> = pubkey, create_txi, txi, log_idx}
         when is_integer(create_txi) and is_integer(txi) and is_integer(log_idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {create_txi, pubkey, txi, log_idx}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  end

  defp deserialize_dex_swaps_cursor(nil), do: {:ok, nil}

  defp deserialize_dex_swaps_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {_from, create_txi, txi, log_idx}
         when is_integer(create_txi) and is_integer(txi) and is_integer(log_idx) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {create_txi, txi, log_idx}}
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

  defp key_boundary(@dex_swap_tokens_table, nil) do
    {
      {0, 0, 0},
      {nil, nil, nil}
    }
  end

  defp key_boundary(@dex_swap_tokens_table, create_txi) do
    {
      {create_txi, 0, 0},
      {create_txi, nil, nil}
    }
  end

  defp key_boundary({<<_pk::256>> = account_pk, create_txi}) do
    {
      {account_pk, create_txi, 0, 0},
      {account_pk, create_txi, nil, nil}
    }
  end

  defp key_boundary(<<_pk::256>> = account_pk) do
    {
      {account_pk, 0, 0, 0},
      {account_pk, nil, nil, nil}
    }
  end

  defp key_boundary(create_txi) do
    {
      {create_txi, <<>>, 0, 0},
      {create_txi, Util.max_256bit_bin(), nil, nil}
    }
  end
end
