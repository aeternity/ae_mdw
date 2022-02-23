defmodule AeMdwWeb.FallbackController do
  @moduledoc """
  Fallback module to deal with AeMdw.Error.Input type exceptions.
  """

  alias AeMdw.Error
  alias AeMdw.Error.Input
  alias Plug.Conn

  use Phoenix.Controller

  @typep error() :: Error.t() | {Input.reason(), Error.value()}

  @spec call(Conn.t(), {:error, error()}) :: Conn.t()
  def call(conn, {:error, %Input{reason: Input.NotFound, message: message}}) do
    conn
    |> put_status(:not_found)
    |> json(%{"error" => message})
  end

  def call(conn, {:error, %Input{message: message}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{"error" => message})
  end

  # hack-ish behavior for exception handling, can be removed once every module adptops the previous form
  def call(conn, {:error, {reason, value}}) do
    call(conn, {:error, reason.exception(value: value)})
  end
end
