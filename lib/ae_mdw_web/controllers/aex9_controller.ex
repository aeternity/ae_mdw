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
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Validate

  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug

  alias Plug.Conn

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_block: 2]
  import AeMdwWeb.Helpers.AexnHelper, only: [normalize_balances: 1]

  import AeMdwWeb.Util,
    only: [
      handle_input: 2,
      parse_range: 1
    ]

  import AeMdwWeb.AexnView

  require Model

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @max_range_length 10

  @spec by_names(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_names(conn, params),
    do: handle_input(conn, fn -> by_names_reply(conn, params) end)

  @spec balance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance(%{assigns: %{state: state}} = conn, %{
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    with {:ok, contract_pk} <- AexnContracts.validate_aex9(contract_id, state),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      balance_reply(conn, contract_pk, account_pk)
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
    with {:ok, height} <- Validate.nonneg_int(height),
         txi when txi != nil <- Util.block_txi(state, {height, -1}),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      account_balances_reply(conn, account_pk, {height, -1})
    else
      {:error, reason} -> {:error, reason}
      nil -> ErrInput.BlockIndex.exception(value: {height, -1})
    end
  end

  def balances(%Conn{assigns: %{state: state}} = conn, %{
        "blockhash" => hash,
        "account_id" => account_id
      }) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, hash} <- Validate.id(hash),
         block_index when block_index != nil <- Util.block_hash_to_bi(state, hash) do
      account_balances_reply(conn, account_pk, block_index)
    else
      {:error, reason} -> {:error, reason}
      nil -> ErrInput.Id.exception(value: hash)
    end
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

  def balances(%Conn{assigns: %{state: state, async_state: async_state, opts: opts}} = conn, %{
        "contract_id" => contract_id
      }) do
    with {:ok, contract_pk} <- AexnContracts.validate_aex9(contract_id, state),
         {:ok, amounts} <- Aex9.fetch_balances(state, async_state, contract_pk, top?(opts)) do
      hash_tuple = DBN.top_height_hash(top?(opts))
      format_json(conn, balances_to_map({amounts, hash_tuple}, contract_pk))
    end
  end

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

  #
  # Private functions
  #

  defp by_names_reply(%Conn{assigns: %{state: state}} = conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, {_prev_cursor, aex9_tokens, _next_cursor}} <-
           AexnTokens.fetch_contracts(state, pagination, :aex9, params, :name, nil, false) do
      format_json(conn, aex9_tokens)
    end
  end

  defp balance_reply(
         %Conn{assigns: %{state: state, async_state: async_state, opts: opts}} = conn,
         contract_pk,
         account_pk
       ) do
    {amount, {type, height, hash}} =
      if top?(opts) do
        case DBN.aex9_balance(contract_pk, account_pk, top?(opts)) do
          {:ok, account_balance} ->
            account_balance

          {:error, reason} ->
            {:error, ErrInput.Aex9BalanceNotAvailable.exception(value: reason)}
        end
      else
        case Aex9.fetch_amount_and_keyblock(state, async_state, contract_pk, account_pk) do
          {:ok, {amount, kb_height_hash}} ->
            {amount, kb_height_hash}

          {:error, unavailable_error} ->
            raise unavailable_error
        end
      end

    format_json(conn, balance_to_map({amount, {type, height, hash}}, contract_pk, account_pk))
  end

  defp balance_for_hash_reply(
         conn,
         contract_pk,
         account_pk,
         {_type, _height, _hash} = height_hash
       ) do
    {:ok, {amount, _}} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
    format_json(conn, balance_to_map({amount, height_hash}, contract_pk, account_pk))
  end

  defp account_balances_reply(
         %Conn{assigns: %{state: state, async_state: async_state}} = conn,
         account_pk
       ) do
    balances =
      state
      |> Contract.aex9_search_contracts(account_pk)
      |> Enum.flat_map(fn contract_pk ->
        case Aex9.fetch_amount(state, async_state, contract_pk, account_pk) do
          {:ok, {amount, call_txi}} ->
            [{amount, call_txi, contract_pk}]

          {:error, _balance_unavailable} ->
            # temporary fallback until remote call txs are completly indexed
            []
        end
      end)
      |> Enum.sort_by(fn {_amount, call_txi, _contract_pk} -> call_txi end, :desc)
      |> Enum.map(&balance_to_map(state, &1))

    format_json(conn, balances)
  end

  defp account_balances_reply(
         %Conn{assigns: %{state: state}} = conn,
         account_pk,
         {kbi, mbi} = block_index
       ) do
    Model.block(hash: block_hash, tx_index: upper_txi) =
      State.fetch!(state, Model.Block, block_index)

    type = if mbi == -1, do: :key, else: :micro

    balances =
      state
      |> Contract.aex9_search_contracts(account_pk)
      |> Enum.flat_map(fn contract_pk ->
        case DBN.aex9_balance(contract_pk, account_pk, {type, kbi, block_hash}) do
          {:ok, {amount, _}} when amount != nil ->
            balance_txi = Contract.aex9_balance_txi(state, contract_pk, upper_txi)
            [{amount, balance_txi, contract_pk}]

          _missing ->
            []
        end
      end)
      |> Enum.map(&balance_to_map(state, &1))

    format_json(conn, balances)
  end

  defp balances_range_reply(conn, contract_pk, range) do
    format_json(
      conn,
      %{
        contract_id: encode_contract(contract_pk),
        range:
          map_balances_range(
            range,
            fn type_height_hash ->
              {amounts, _height_hash} = DBN.aex9_balances!(contract_pk, type_height_hash)
              {:amounts, normalize_balances(amounts)}
            end
          )
      }
    )
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
        else
          {:ok, first..last}
        end

      {:error, _detail} ->
        {:error, ErrInput.NotAex9.exception(value: range)}
    end
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
         {:ok, Model.aexn_contract(txi_idx: {txi, _idx})} <-
           State.get(state, Model.AexnContract, {:aex9, ct_pk}) do
      Model.tx(block_index: contract_block_index) = State.fetch!(state, Model.Tx, txi)

      if contract_block_index <= block_index do
        {:ok, ct_pk}
      else
        {:error, ErrInput.NotFound.exception(value: ct_id)}
      end
    else
      {:error, {ErrInput.Id, id}} ->
        {:error, ErrInput.Id.exception(value: id)}

      :not_found ->
        # if not yet synced by Mdw but present on Node
        with {:ok, ct_pk} <- Validate.id(ct_id) do
          if AexnContracts.is_aex9?(ct_pk) do
            {:ok, ct_pk}
          else
            {:error, ErrInput.NotAex9.exception(value: ct_id)}
          end
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
      Map.put(%{height: height, block_hash: encode_block(:key, hash)}, k, v)
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
