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

  import AeMdwWeb.AexnView

  require Model

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec by_names(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_names(%Conn{assigns: %{state: state}} = conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, {_prev_cursor, aex9_tokens, _next_cursor}} <-
           AexnTokens.fetch_contracts(state, pagination, :aex9, params, :name, nil, false) do
      format_json(conn, aex9_tokens)
    end
  end

  @spec balance_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance_for_hash(%Conn{assigns: %{state: state}} = conn, %{
        "blockhash" => block_hash_enc,
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    with {:ok, {_type, _height, hash} = height_hash} <- ensure_block_hash(block_hash_enc),
         {:ok, contract_pk} <- ensure_aex9_contract_at_block(state, contract_id, hash),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      {:ok, {amount, _}} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
      format_json(conn, balance_to_map({amount, height_hash}, contract_pk, account_pk))
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

  def balances(conn, %{"account_id" => account_id}) do
    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      account_balances_reply(conn, account_pk)
    end
  end

  def balances(%Conn{assigns: %{state: state, async_state: async_state, opts: opts}} = conn, %{
        "contract_id" => contract_id
      }) do
    with {:ok, contract_pk} <- AexnContracts.validate_aex9(contract_id, state),
         {:ok, amounts} <- Aex9.fetch_balances(state, async_state, contract_pk, top?(opts)) do
      hash_tuple = DBN.top_height_hash(top?(opts))
      format_json(conn, balances_to_map({amounts, hash_tuple}, contract_pk))
    end
  end

  #
  # Private functions
  #

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
end
