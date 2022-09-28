defmodule AeMdwWeb.Aex9Controller do
  @moduledoc """
  Controller for AEX9 v1 endpoints.
  """

  use AeMdwWeb, :controller

  alias AeMdw.Aex9
  alias AeMdw.AexnContracts
  alias AeMdw.AexnTokens
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Validate

  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug

  alias Plug.Conn

  import AeMdwWeb.Util,
    only: [
      handle_input: 2,
      parse_range: 1
    ]

  import AeMdwWeb.Helpers.AexnHelper
  import AeMdwWeb.AexnView

  require Model

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
  def balance_range(%Conn{assigns: %{state: state}} = conn, %{
        "range" => range,
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    with {:ok, first..last} <- validate_range(range),
         {:ok, contract_pk} <-
           ensure_aex9_contract_at_block(state, contract_id, {min(first, last), -1}),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      handle_input(
        conn,
        fn ->
          balance_range_reply(
            conn,
            contract_pk,
            account_pk,
            first..last
          )
        end
      )
    end
  end

  @spec balance_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance_for_hash(%Conn{assigns: %{state: state}} = conn, %{
        "blockhash" => block_hash_enc,
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    with {:ok, {type, height, hash}} <- ensure_block_hash(block_hash_enc),
         {:ok, contract_pk} <- ensure_aex9_contract_at_block(state, contract_id, hash),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      handle_input(
        conn,
        fn ->
          balance_for_hash_reply(
            conn,
            contract_pk,
            account_pk,
            {type, height, hash}
          )
        end
      )
    end
  end

  @spec balances(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances(%Conn{assigns: %{state: state}} = conn, %{
        "height" => height,
        "account_id" => account_id
      }) do
    handle_input(
      conn,
      fn ->
        height = Validate.nonneg_int!(height)

        if nil == Util.block_txi(state, {height, -1}) do
          raise ErrInput.BlockIndex, value: {height, -1}
        end

        account_pk = Validate.id!(account_id, [:account_pubkey])

        account_balances_reply(conn, account_pk, {height, -1})
      end
    )
  end

  def balances(%Conn{assigns: %{state: state}} = conn, %{
        "blockhash" => hash,
        "account_id" => account_id
      }) do
    handle_input(
      conn,
      fn ->
        account_pk = Validate.id!(account_id, [:account_pubkey])

        block_index =
          Util.block_hash_to_bi(state, Validate.id!(hash)) ||
            raise ErrInput.Id, value: hash

        account_balances_reply(conn, account_pk, block_index)
      end
    )
  end

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
  def balances_range(%Conn{assigns: %{state: state}} = conn, %{
        "range" => range,
        "contract_id" => contract_id
      }) do
    with {:ok, first..last} <- validate_range(range),
         {:ok, contract_pk} <-
           ensure_aex9_contract_at_block(state, contract_id, {min(first, last), -1}) do
      handle_input(
        conn,
        fn ->
          balances_range_reply(conn, contract_pk, first..last)
        end
      )
    end
  end

  @spec balances_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances_for_hash(%Conn{assigns: %{state: state}} = conn, %{
        "blockhash" => block_hash_enc,
        "contract_id" => contract_id
      }) do
    with {:ok, {type, height, hash}} <- ensure_block_hash(block_hash_enc),
         {:ok, contract_pk} <- ensure_aex9_contract_at_block(state, contract_id, hash) do
      handle_input(
        conn,
        fn ->
          balances_for_hash_reply(conn, contract_pk, {type, height, hash})
        end
      )
    end
  end

  #
  # Private functions
  #
  defp by_contract_reply(%Conn{assigns: %{state: state}} = conn, contract_id) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aex9} <- AexnTokens.fetch_contract(state, {:aex9, contract_pk}) do
      json(conn, %{data: render_contract(state, m_aex9)})
    end
  end

  defp by_names_reply(%Conn{assigns: %{state: state}} = conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_contracts(state, pagination, :aex9, params, :name, nil) do
      json(conn, render_contracts(state, aex9_tokens))
    end
  end

  defp by_symbols_reply(%Conn{assigns: %{state: state}} = conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_contracts(state, pagination, :aex9, params, :symbol, nil) do
      json(conn, render_contracts(state, aex9_tokens))
    end
  end

  defp balance_reply(%Conn{assigns: %{state: state, opts: opts}} = conn, contract_pk, account_pk) do
    {amount, {type, height, hash}} =
      if top?(opts) do
        case DBN.aex9_balance(contract_pk, account_pk, top?(opts)) do
          {:ok, account_balance} ->
            account_balance

          {:error, reason} ->
            {:error, ErrInput.Aex9BalanceNotAvailable.exception(value: reason)}
        end
      else
        case Aex9.fetch_amount_and_keyblock(state, contract_pk, account_pk) do
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
              {:ok, {amount, _}} = DBN.aex9_balance(contract_pk, account_pk, type_height_hash)
              {:amount, amount}
            end
          )
      }
    )
  end

  defp balance_for_hash_reply(
         conn,
         contract_pk,
         account_pk,
         {_type, _height, _hash} = height_hash
       ) do
    {:ok, {amount, _}} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
    json(conn, balance_to_map({amount, height_hash}, contract_pk, account_pk))
  end

  defp account_balances_reply(%Conn{assigns: %{state: state}} = conn, account_pk) do
    balances =
      state
      |> Contract.aex9_search_contracts(account_pk)
      |> Enum.flat_map(fn contract_pk ->
        case Aex9.fetch_amount(state, contract_pk, account_pk) do
          {:ok, {amount, call_txi}} ->
            [{amount, call_txi, contract_pk}]

          {:error, _balance_unavailable} ->
            # temporary fallback until remote call txs are completly indexed
            []
        end
      end)
      |> Enum.sort_by(fn {_amount, call_txi, _contract_pk} -> call_txi end, :desc)
      |> Enum.map(&balance_to_map(state, &1))

    json(conn, balances)
  end

  defp account_balances_reply(
         %Conn{assigns: %{state: state}} = conn,
         account_pk,
         {kbi, mbi} = block_index
       ) do
    Model.block(hash: block_hash) = State.fetch!(state, Model.Block, block_index)

    type = if mbi == -1, do: :key, else: :micro

    balances =
      state
      |> Contract.aex9_search_contracts(account_pk)
      |> Enum.flat_map(fn contract_pk ->
        create_txi = Origin.tx_index!(state, {:contract, contract_pk})

        case DBN.aex9_balance(contract_pk, account_pk, {type, kbi, block_hash}) do
          {:ok, {amount, _}} when amount != nil -> [{amount, create_txi, contract_pk}]
          _missing -> []
        end
      end)
      |> Enum.map(&balance_to_map(state, &1))

    json(conn, balances)
  end

  defp balances_reply(%Conn{assigns: %{state: state, opts: opts}} = conn, contract_pk) do
    amounts = Aex9.fetch_balances(state, contract_pk, top?(opts))
    hash_tuple = DBN.top_height_hash(top?(opts))
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

  defp balances_for_hash_reply(conn, contract_pk, {_type, _height, _hash} = height_hash) do
    {amounts, _} = DBN.aex9_balances!(contract_pk, height_hash)
    json(conn, balances_to_map({amounts, height_hash}, contract_pk))
  end

  defp validate_range(range) do
    case parse_range(range) do
      {:ok, first..last} ->
        {:ok, top_kb} = :aec_chain.top_key_block()
        first = max(0, first)
        last = min(last, :aec_blocks.height(top_kb))

        if last - first + 1 > @max_range_length do
          {:error,
           ErrInput.RangeTooBig.exception(value: "max range length is #{@max_range_length}")}
        end

        {:ok, first..last}

      {:error, _detail} ->
        {:error, ErrInput.NotAex9.exception(value: range)}
    end
  end

  defp ensure_aex9_contract_pk!(ct_ident) do
    pk = Validate.id!(ct_ident, [:contract_pubkey])
    AexnContracts.is_aex9?(pk) || raise ErrInput.NotAex9, value: ct_ident
    pk
  end

  defp ensure_aex9_contract_at_block(state, ct_id, block_hash) when is_binary(block_hash) do
    case Util.block_hash_to_bi(state, block_hash) do
      nil ->
        {:error, ErrInput.NotFound.exception(value: block_hash)}

      block_index ->
        ensure_aex9_contract_at_block(state, ct_id, block_index)
    end
  end

  defp ensure_aex9_contract_at_block(state, ct_id, block_index) do
    with {:ok, ct_pk} <- Validate.id(ct_id, [:contract_pubkey]),
         {:ok, Model.aexn_contract(txi: txi)} <-
           State.get(state, Model.AexnContract, {:aex9, ct_pk}) do
      if txi < Util.block_txi(state, block_index) do
        {:ok, ct_pk}
      else
        {:error, ErrInput.NotFound.exception(value: ct_id)}
      end
    else
      {:error, {ErrInput.Id, id}} ->
        {:error, ErrInput.Id.exception(value: id)}

      :not_found ->
        # if not yet synced by Mdw but present on Node
        ct_pk = Validate.id!(ct_id)

        if AexnContracts.is_aex9?(ct_pk) do
          {:ok, ct_pk}
        else
          {:error, ErrInput.NotAex9.exception(value: ct_id)}
        end
    end
  end

  defp ensure_block_hash(block_ident) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_ident) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} ->
            {:ok, {:aec_blocks.type(block), :aec_blocks.height(block), block_hash}}

          :error ->
            {:error, ErrInput.NotFound.exception(value: block_ident)}
        end

      _any_error ->
        {:error, ErrInput.Query.exception(value: block_ident)}
    end
  end

  defp top?(opts), do: Keyword.get(opts, :top?, false)

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
