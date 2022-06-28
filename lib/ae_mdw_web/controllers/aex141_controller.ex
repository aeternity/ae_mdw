defmodule AeMdwWeb.Aex141Controller do
  @moduledoc """
  Controller for specific AEX141 endpoints.
  """

  use AeMdwWeb, :controller

  alias AeMdw.Aex141
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util, as: WebUtil

  alias Plug.Conn

  import AeMdwWeb.Helpers.AexnHelper

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec nft_owner(Conn.t(), map()) :: Conn.t()
  def nft_owner(conn, %{"contract_id" => contract_id, "token_id" => token_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {token_id, ""} <- Integer.parse(token_id),
         {:ok, account_pk} <- Aex141.fetch_nft_owner(contract_pk, token_id) do
      json(conn, %{data: enc_id(account_pk)})
    else
      :error ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      error ->
        error
    end
  end

  @spec owned_nfts(Conn.t(), map()) :: Conn.t() | {:error, ErrInput.t()}
  def owned_nfts(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, account_pk} <- Validate.id(account_id),
         {:ok, {prev_cursor, nfts, next_cursor}} <-
           Aex141.fetch_owned_nfts(state, account_pk, cursor, pagination) do
      WebUtil.paginate(conn, prev_cursor, nfts, next_cursor)
    end
  end
end
