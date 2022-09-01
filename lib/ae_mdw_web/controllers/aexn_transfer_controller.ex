defmodule AeMdwWeb.AexnTransferController do
  @moduledoc """
  AEX-n transfer endpoints.
  """

  use AeMdwWeb, :controller

  alias AeMdw.AexnTransfers
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug

  alias Plug.Conn

  import AeMdwWeb.Util,
    only: [
      handle_input: 2,
      paginate: 4
    ]

  import AeMdwWeb.AexnView

  require Model

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec transfers_from_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_v1(conn, %{"sender" => sender_id}),
    do:
      handle_input(
        conn,
        fn ->
          transfers_reply(conn, {:from, Validate.id!(sender_id)}, &sender_transfer_to_map/2)
        end
      )

  @spec transfers_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_to_v1(conn, %{"recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn ->
          transfers_reply(conn, {:to, Validate.id!(recipient_id)}, &recipient_transfer_to_map/2)
        end
      )

  @spec transfers_from_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_to_v1(conn, %{"sender" => sender_id, "recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn ->
          query = {:from_to, Validate.id!(sender_id), Validate.id!(recipient_id)}
          transfers_reply(conn, query, &pair_transfer_to_map/2)
        end
      )

  @spec aex9_transfers_from(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex9_transfers_from(conn, %{"sender" => sender_id}) do
    transfers_from_reply(conn, :aex9, sender_id)
  end

  @spec aex9_transfers_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex9_transfers_to(conn, %{"recipient" => recipient_id}) do
    transfers_to_reply(conn, :aex9, recipient_id)
  end

  @spec aex9_transfers_from_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex9_transfers_from_to(conn, %{"sender" => sender_id, "recipient" => recipient_id}) do
    transfers_pair_reply(conn, :aex9, sender_id, recipient_id)
  end

  @spec aex141_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex141_transfers(conn, %{"contract_id" => contract_id}) do
    contract_transfers_reply(conn, contract_id, {:from, nil})
  end

  @spec aex141_transfers_from(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex141_transfers_from(conn, %{"contract_id" => contract_id, "sender" => sender_id}) do
    with {:ok, sender_pk} <- Validate.id(sender_id, [:account_pubkey]) do
      contract_transfers_reply(conn, contract_id, {:from, sender_pk})
    end
  end

  def aex141_transfers_from(conn, %{"sender" => sender_id}) do
    transfers_from_reply(conn, :aex141, sender_id)
  end

  @spec aex141_transfers_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex141_transfers_to(conn, %{"contract_id" => contract_id, "recipient" => recipient_id}) do
    with {:ok, recipient_pk} <- Validate.id(recipient_id, [:account_pubkey]) do
      contract_transfers_reply(conn, contract_id, {:to, recipient_pk})
    end
  end

  def aex141_transfers_to(conn, %{"recipient" => recipient_id}) do
    transfers_to_reply(conn, :aex141, recipient_id)
  end

  @spec aex141_transfers_from_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def aex141_transfers_from_to(conn, %{"sender" => sender_id, "recipient" => recipient_id}) do
    transfers_pair_reply(conn, :aex141, sender_id, recipient_id)
  end

  #
  # Private functions
  #
  defp transfers_reply(%Conn{assigns: %{state: state}} = conn, query, transfer_to_map_fn) do
    transfers =
      state
      |> Contract.aex9_search_transfers(query)
      |> Enum.map(&transfer_to_map_fn.(state, &1))

    json(conn, transfers)
  end

  defp contract_transfers_reply(%Conn{assigns: assigns} = conn, contract_id, tagged_account_pk) do
    %{pagination: pagination, cursor: cursor, state: state} = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, create_txi} <- Origin.tx_index(state, {:contract, contract_pk}) do
      {prev_cursor, transfers_keys, next_cursor} =
        AexnTransfers.fetch_contract_transfers(
          state,
          create_txi,
          tagged_account_pk,
          pagination,
          cursor
        )

      data = Enum.map(transfers_keys, &contract_transfer_to_map(state, &1))

      paginate(conn, prev_cursor, data, next_cursor)
    else
      :not_found -> {:error, ErrInput.NotFound.exception(value: contract_id)}
      error -> error
    end
  end

  defp transfers_from_reply(%Conn{assigns: assigns} = conn, aexn_type, sender_id) do
    %{pagination: pagination, cursor: cursor, state: state} = assigns

    with {:ok, sender_pk} <- Validate.id(sender_id, [:account_pubkey]) do
      {prev_cursor, transfers_keys, next_cursor} =
        AexnTransfers.fetch_sender_transfers(state, aexn_type, sender_pk, pagination, cursor)

      data = Enum.map(transfers_keys, &sender_transfer_to_map(state, &1))

      paginate(conn, prev_cursor, data, next_cursor)
    end
  end

  defp transfers_to_reply(%Conn{assigns: assigns} = conn, aexn_type, recipient_id) do
    %{pagination: pagination, cursor: cursor, state: state} = assigns

    with {:ok, recipient_pk} <- Validate.id(recipient_id, [:account_pubkey]) do
      {prev_cursor, transfers_keys, next_cursor} =
        AexnTransfers.fetch_recipient_transfers(
          state,
          aexn_type,
          recipient_pk,
          pagination,
          cursor
        )

      data = Enum.map(transfers_keys, &recipient_transfer_to_map(state, &1))

      paginate(conn, prev_cursor, data, next_cursor)
    end
  end

  defp transfers_pair_reply(%Conn{assigns: assigns} = conn, aexn_type, sender_id, recipient_id) do
    %{pagination: pagination, cursor: cursor, state: state} = assigns

    with {:ok, sender_pk} <- Validate.id(sender_id, [:account_pubkey]),
         {:ok, recipient_pk} <- Validate.id(recipient_id, [:account_pubkey]) do
      {prev_cursor, transfers_keys, next_cursor} =
        AexnTransfers.fetch_pair_transfers(
          state,
          aexn_type,
          sender_pk,
          recipient_pk,
          pagination,
          cursor
        )

      data = Enum.map(transfers_keys, &pair_transfer_to_map(state, &1))

      paginate(conn, prev_cursor, data, next_cursor)
    end
  end
end
