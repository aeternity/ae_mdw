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

  @spec collection_owners(Conn.t(), map()) :: Conn.t()
  def collection_owners(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, {prev_cursor, nft_owners, next_cursor}} <-
           Aex141.fetch_collection_owners(state, contract_pk, cursor, pagination) do
      WebUtil.paginate(conn, prev_cursor, nft_owners, next_cursor)
    end
  end

  @spec collection_templates(Conn.t(), map()) :: Conn.t() | {:error, ErrInput.t()}
  def collection_templates(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id),
         {:ok, {prev_cursor, templates, next_cursor}} <-
           Aex141.fetch_templates(state, contract_pk, cursor, pagination) do
      WebUtil.paginate(conn, prev_cursor, templates, next_cursor)
    end
  end

  @spec nft_owner(Conn.t(), map()) :: Conn.t()
  def nft_owner(conn, %{"contract_id" => contract_id, "token_id" => token_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:int, {token_id, ""}} <- {:int, Integer.parse(token_id)},
         {:ok, account_pk} <- Aex141.fetch_nft_owner(contract_pk, token_id) do
      json(conn, %{data: enc_id(account_pk)})
    else
      :error ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      {:int, _invalid_int} ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      {:error, reason} ->
        {:error, reason}
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
