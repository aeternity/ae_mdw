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
  alias AeMdwWeb.Util

  alias Plug.Conn

  import AeMdw.Util.Encoding, only: [encode_account: 1]

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
      Util.render(conn, prev_cursor, nft_owners, next_cursor)
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
         {:ok, paginated_templates} <-
           Aex141.fetch_templates(state, contract_pk, cursor, pagination) do
      Util.render(conn, paginated_templates)
    end
  end

  @spec collection_template_tokens(Conn.t(), map()) :: Conn.t() | {:error, ErrInput.t()}
  def collection_template_tokens(%Conn{assigns: assigns} = conn, %{
        "contract_id" => contract_id,
        "template_id" => template_id
      }) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id),
         {template_id, ""} <- Integer.parse(template_id),
         {:ok, paginated_tokens} <-
           Aex141.fetch_template_tokens(state, contract_pk, template_id, cursor, pagination) do
      Util.render(conn, paginated_tokens)
    end
  end

  @spec nft_metadata(Conn.t(), map()) :: Conn.t()
  def nft_metadata(%Conn{assigns: %{state: state}} = conn, %{
        "contract_id" => contract_id,
        "token_id" => token_id
      }) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:int, {token_id, ""}} <- {:int, Integer.parse(token_id)},
         {:ok, metadata} <- Aex141.fetch_nft_metadata(state, contract_pk, token_id) do
      format_json(conn, %{data: metadata})
    else
      {:error, reason} ->
        {:error, reason}

      _token_not_found ->
        {:error, ErrInput.NotFound.exception(value: token_id)}
    end
  end

  @spec nft_owner(Conn.t(), map()) :: Conn.t()
  def nft_owner(%Conn{assigns: %{state: state}} = conn, %{
        "contract_id" => contract_id,
        "token_id" => token_id
      }) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:int, {token_id, ""}} <- {:int, Integer.parse(token_id)},
         {:ok, account_pk} <- Aex141.fetch_nft_owner(state, contract_pk, token_id) do
      format_json(conn, %{data: encode_account(account_pk)})
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
  def owned_nfts(%Conn{assigns: assigns} = conn, %{"account_id" => account_id} = params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, account_pk} <- Validate.id(account_id),
         {:ok, contract_pk} <- validate_optional_pubkey(params, "contract"),
         {:ok, {prev_cursor, nfts, next_cursor}} <-
           Aex141.fetch_owned_nfts(state, account_pk, contract_pk, cursor, pagination) do
      Util.render(conn, prev_cursor, nfts, next_cursor)
    end
  end

  defp validate_optional_pubkey(params, param_name) do
    case Map.fetch(params, param_name) do
      {:ok, id} -> Validate.id(id)
      :error -> {:ok, nil}
    end
  end
end
