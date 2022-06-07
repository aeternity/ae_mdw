defmodule AeMdwWeb.Aex9Controller do
  @moduledoc """
  Controller for AEX9 v1 endpoints.
  """

  use AeMdwWeb, :controller

  alias AeMdw.Aex9
  alias AeMdw.AexnTokens
  alias AeMdw.AexnContracts
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Util
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Validate

  alias AeMdwWeb.DataStreamPlug, as: DSPlug
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug

  alias Plug.Conn

  import AeMdwWeb.Util, only: [handle_input: 2, paginate: 4, presence?: 2]
  import AeMdwWeb.Helpers.AexnHelper
  import AeMdwWeb.AexnView

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @max_range_length 10

  @spec by_contract(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_contract(conn, %{"id" => contract_id}),
    do: handle_input(conn, fn -> by_contract_reply(conn, contract_id) end)

  @spec by_names(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_names(conn, params),
    do: handle_input(conn, fn -> by_names_reply(conn, params) end)

  @spec by_symbols(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_symbols(conn, params),
    do: handle_input(conn, fn -> by_symbols_reply(conn, params) end)

  @spec balance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance(conn, %{"contract_id" => contract_id, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          balance_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            Validate.id!(account_id, [:account_pubkey])
          )
        end
      )

  @spec balance_range(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance_range(conn, %{
        "range" => range,
        "contract_id" => contract_id,
        "account_id" => account_id
      }),
      do:
        handle_input(
          conn,
          fn ->
            balance_range_reply(
              conn,
              ensure_aex9_contract_pk!(contract_id),
              Validate.id!(account_id, [:account_pubkey]),
              parse_range!(range)
            )
          end
        )

  @spec balance_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance_for_hash(conn, %{
        "blockhash" => block_hash_enc,
        "contract_id" => contract_id,
        "account_id" => account_id
      }),
      do:
        handle_input(
          conn,
          fn ->
            balance_for_hash_reply(
              conn,
              ensure_aex9_contract_pk!(contract_id),
              Validate.id!(account_id, [:account_pubkey]),
              ensure_block_hash_and_height!(block_hash_enc)
            )
          end
        )

  @spec balances(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances(conn, %{"height" => height, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])

          txi =
            Util.block_txi(Validate.nonneg_int!(height)) ||
              raise ErrInput.BlockIndex, value: height

          account_balances_reply(conn, account_pk, txi)
        end
      )

  def balances(conn, %{"blockhash" => hash, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])

          bi =
            Util.block_hash_to_bi(Validate.id!(hash)) ||
              raise ErrInput.Id, value: hash

          account_balances_reply(conn, account_pk, Util.block_txi(bi))
        end
      )

  def balances(conn, %{"account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])
          account_balances_reply(conn, account_pk)
        end
      )

  def balances(conn, %{"contract_id" => contract_id}),
    do: handle_input(conn, fn -> balances_reply(conn, ensure_aex9_contract_pk!(contract_id)) end)

  @spec balances_range(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances_range(conn, %{"range" => range, "contract_id" => contract_id}),
    do:
      handle_input(
        conn,
        fn ->
          balances_range_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            parse_range!(range)
          )
        end
      )

  @spec balances_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances_for_hash(conn, %{"blockhash" => block_hash_enc, "contract_id" => contract_id}),
    do:
      handle_input(
        conn,
        fn ->
          balances_for_hash_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            ensure_block_hash_and_height!(block_hash_enc)
          )
        end
      )

  @spec transfers_from_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_v1(conn, %{"sender" => sender_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:from, Validate.id!(sender_id)}, :aex9_transfer) end
      )

  @spec transfers_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_to_v1(conn, %{"recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:to, Validate.id!(recipient_id)}, :rev_aex9_transfer) end
      )

  @spec transfers_from_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_to_v1(conn, %{"sender" => sender_id, "recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn ->
          query = {:from_to, Validate.id!(sender_id), Validate.id!(recipient_id)}
          transfers_reply(conn, query, :aex9_pair_transfer)
        end
      )

  @spec transfers_from(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from(%Conn{assigns: assigns} = conn, %{"sender" => sender_id}) do
    %{pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, transfers_keys, next_cursor} =
      sender_id
      |> Validate.id!()
      |> Aex9.fetch_sender_transfers(pagination, cursor)

    data = Enum.map(transfers_keys, &sender_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  @spec transfers_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_to(%Conn{assigns: assigns} = conn, %{"recipient" => recipient_id}) do
    %{pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, transfers_keys, next_cursor} =
      recipient_id
      |> Validate.id!()
      |> Aex9.fetch_recipient_transfers(pagination, cursor)

    data = Enum.map(transfers_keys, &recipient_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  @spec transfers_from_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_to(%Conn{assigns: assigns} = conn, %{
        "sender" => sender_id,
        "recipient" => recipient_id
      }) do
    %{pagination: pagination, cursor: cursor} = assigns

    sender_pk = Validate.id!(sender_id)
    recipient_pk = Validate.id!(recipient_id)

    {prev_cursor, transfers_keys, next_cursor} =
      Aex9.fetch_pair_transfers(sender_pk, recipient_pk, pagination, cursor)

    data = Enum.map(transfers_keys, &pair_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  #
  # Private functions
  #
  defp transfers_reply(conn, query, key_tag) do
    transfers =
      query
      |> Contract.aex9_search_transfers()
      |> Stream.map(&transfer_to_map(&1, key_tag))
      |> Enum.sort_by(fn %{call_txi: call_txi} -> call_txi end)

    json(conn, transfers)
  end

  defp by_contract_reply(conn, contract_id) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aex9} <- AexnTokens.fetch_token({:aex9, contract_pk}) do
      json(conn, %{data: render_token(m_aex9)})
    end
  end

  defp by_names_reply(conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_tokens(pagination, :aex9, params, :name, nil) do
      json(conn, render_tokens(aex9_tokens))
    end
  end

  defp by_symbols_reply(conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_tokens(pagination, :aex9, params, :symbol, nil) do
      json(conn, render_tokens(aex9_tokens))
    end
  end

  defp balance_reply(conn, contract_pk, account_pk) do
    {amount, {type, height, hash}} =
      if top?(conn) do
        DBN.aex9_balance(contract_pk, account_pk, top?(conn))
      else
        case Aex9.fetch_amount_and_keyblock(contract_pk, account_pk) do
          {:ok, {amount, kb_height_hash}} ->
            {amount, kb_height_hash}

          {:error, unavailable_error} ->
            raise unavailable_error
        end
      end

    json(conn, balance_to_map({amount, {type, height, hash}}, contract_pk, account_pk))
  end

  defp balance_range_reply(conn, contract_pk, account_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        account_id: enc_id(account_pk),
        range:
          map_balances_range(
            range,
            fn type_height_hash ->
              {amount, _} = DBN.aex9_balance(contract_pk, account_pk, type_height_hash)
              {:amount, amount}
            end
          )
      }
    )
  end

  defp balance_for_hash_reply(conn, contract_pk, account_pk, {type, block_hash, height}) do
    {amount, _} = DBN.aex9_balance(contract_pk, account_pk, {type, height, block_hash})
    json(conn, balance_to_map({amount, {type, height, block_hash}}, contract_pk, account_pk))
  end

  defp account_balances_reply(conn, account_pk) do
    balances =
      account_pk
      |> Contract.aex9_search_contracts()
      |> Enum.flat_map(fn contract_pk ->
        case Aex9.fetch_amount(contract_pk, account_pk) do
          {:ok, {amount, call_txi}} ->
            [{amount, call_txi, contract_pk}]

          {:error, _balance_unavailable} ->
            # temporary fallback until remote call txs are completly indexed
            []
        end
      end)
      |> Enum.map(&balance_to_map/1)

    json(conn, balances)
  end

  defp account_balances_reply(conn, account_pk, last_txi) do
    contracts =
      account_pk
      |> Contract.aex9_search_contract(last_txi)
      |> Map.to_list()
      |> Enum.sort_by(fn {_ct_pk, txi_list} -> _call_txi = List.last(txi_list) end)

    height_hash = DBN.top_height_hash(top?(conn))

    balances =
      contracts
      |> Enum.map(fn {contract_pk, txi_list} ->
        {amount, _} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
        call_txi = List.last(txi_list)
        {amount, call_txi, contract_pk}
      end)
      |> Enum.map(&balance_to_map/1)

    json(conn, balances)
  end

  defp balances_reply(conn, contract_pk) do
    amounts = Aex9.fetch_balances(contract_pk, top?(conn))
    hash_tuple = DBN.top_height_hash(top?(conn))
    json(conn, balances_to_map({amounts, hash_tuple}, contract_pk))
  end

  defp balances_range_reply(conn, contract_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        range:
          map_balances_range(
            range,
            fn type_height_hash ->
              {amounts, _} = DBN.aex9_balances!(contract_pk, type_height_hash)
              {:amounts, normalize_balances(amounts)}
            end
          )
      }
    )
  end

  defp balances_for_hash_reply(conn, contract_pk, {block_type, block_hash, height}) do
    {amounts, _} = DBN.aex9_balances!(contract_pk, {block_type, height, block_hash})
    json(conn, balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk))
  end

  defp parse_range!(range) do
    case DSPlug.parse_range(range) do
      {:ok, %Range{first: f, last: l}} ->
        {:ok, top_kb} = :aec_chain.top_key_block()
        first = max(0, f)
        last = min(l, :aec_blocks.height(top_kb))

        if last - first + 1 > @max_range_length do
          raise ErrInput.RangeTooBig, value: "max range length is #{@max_range_length}"
        end

        first..last

      {:error, _detail} ->
        raise ErrInput.NotAex9, value: range
    end
  end

  defp ensure_aex9_contract_pk!(ct_ident) do
    pk = Validate.id!(ct_ident, [:contract_pubkey])
    AexnContracts.is_aex9?(pk) || raise ErrInput.NotAex9, value: ct_ident
    pk
  end

  defp ensure_block_hash_and_height!(block_ident) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_ident) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} ->
            {:aec_blocks.type(block), block_hash, :aec_blocks.height(block)}

          :error ->
            raise ErrInput.NotFound, value: block_ident
        end

      _any_error ->
        raise ErrInput.Query, value: block_ident
    end
  end

  defp top?(conn), do: presence?(conn, "top")

  defp map_balances_range(range, get_balance_func) do
    range
    |> Stream.map(&height_hash/1)
    |> Stream.map(fn {height, hash} ->
      {k, v} = get_balance_func.({:key, height, hash})
      Map.put(%{height: height, block_hash: enc_block(:key, hash)}, k, v)
    end)
    |> Enum.to_list()
  end

  defp height_hash(height) do
    with {:ok, block} <- :aec_chain.get_key_block_by_height(height),
         {:ok, hash} <- :aec_headers.hash_header(:aec_blocks.to_header(block)) do
      {height, hash}
    else
      _error -> {height, <<>>}
    end
  end
end
