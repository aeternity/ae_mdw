defmodule AeMdw.Dex do
  @moduledoc """
  Search for DEX swaps.
  """

  import AeMdwWeb.AexnView, only: [render_swap: 2]

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util

  require Model

  @account_swaps_table Model.DexAccountSwapTokens
  @contract_swaps_table Model.DexContractSwapTokens

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @type swap :: %{
          caller: pubkey(),
          to: pubkey(),
          token_from: String.t(),
          token_to: String.t(),
          amounts: list(integer())
        }

  @type paginated_swaps ::
          {page_cursor(), [swap()], page_cursor()}

  @typep account_query :: pubkey() | {pubkey(), integer()}
  @typep cursor :: binary()
  @typep pagination :: Collection.direction_limit()
  @typep page_cursor :: Collection.pagination_cursor()

  @spec fetch_account_swaps(State.t(), account_query(), pagination(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_account_swaps(state, query, pagination, cursor) do
    with {:ok, cursor} <- deserialize_account_cursor(cursor) do
      state
      |> build_streamer(@account_swaps_table, key_boundary(query), cursor)
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(fn paginated_swaps -> {:ok, paginated_swaps} end)
    end
  end

  @spec fetch_contract_swaps(State.t(), pubkey(), pagination(), cursor()) ::
          {:ok, paginated_swaps()} | {:error, Error.t()}
  def fetch_contract_swaps(state, create_txi, pagination, cursor) do
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

  defp serialize_cursor(cursor_tuple) do
    cursor_tuple
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
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
