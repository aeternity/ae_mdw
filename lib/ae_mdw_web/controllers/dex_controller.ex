defmodule AeMdwWeb.DexController do
  @moduledoc """
  DEX endpoints.
  """
  use AeMdwWeb, :controller

  import AeMdwWeb.AexnView, only: [render_swap: 2]

  alias AeMdw.Dex
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Sync.DexCache
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec swaps(Conn.t(), map()) :: Conn.t()
  def swaps(%Conn{assigns: assigns} = conn, %{
        "caller" => account_id,
        "from_symbol" => token_symbol
      }) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, create_txi} <- validate_token(token_symbol),
         {:ok, swaps} <-
           Dex.fetch_account_swaps(state, {account_pk, create_txi}, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"caller" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, swaps} <- Dex.fetch_account_swaps(state, account_pk, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"from_symbol" => token_symbol}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, create_txi} <- validate_token(token_symbol),
         {:ok, swaps} <- Dex.fetch_contract_swaps(state, create_txi, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  @spec swaps_for_contract(Conn.t(), map()) :: Conn.t()
  def swaps_for_contract(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, create_txi} <- validate_contract_pk(contract_pk, state, contract_id),
         {:ok, swaps} <- Dex.fetch_contract_swaps(state, create_txi, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  defp validate_contract_pk(contract_pk, state, contract_id) do
    case DexCache.get_contract_pk_txi(contract_pk, state) do
      nil -> {:error, ErrInput.NotAex9.exception(value: contract_id)}
      create_txi -> {:ok, create_txi}
    end
  end

  defp validate_token(token_symbol) do
    case DexCache.get_token_pair_txi(token_symbol) do
      nil -> {:error, ErrInput.NotAex9.exception(value: token_symbol)}
      create_txi -> {:ok, create_txi}
    end
  end
end
