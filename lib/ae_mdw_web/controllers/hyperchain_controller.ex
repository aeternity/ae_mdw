defmodule AeMdwWeb.HyperchainController do
  use AeMdwWeb, :controller

  alias AeMdw.Hyperchain
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util, as: WebUtil
  alias AeMdwWeb.Plugs.HyperchainPlug
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  plug(HyperchainPlug)
  plug(PaginatedPlug, order_by: ~w(expiration activation deactivation name)a)
  action_fallback(FallbackController)

  @spec epochs(Conn.t(), map()) :: Conn.t()
  def epochs(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    with {:ok, epochs} <-
           Hyperchain.fetch_epochs(state, pagination, scope, cursor) do
      WebUtil.render(conn, epochs)
    end
  end

  @spec schedule(Conn.t(), map()) :: Conn.t()
  def schedule(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    with {:ok, schedule} <-
           Hyperchain.fetch_leaders_schedule(state, pagination, scope, cursor) do
      WebUtil.render(conn, schedule)
    end
  end

  @spec schedule_at_height(Conn.t(), map()) :: Conn.t()
  def schedule_at_height(%Conn{assigns: %{state: state}} = conn, %{"height" => height}) do
    with {:ok, height} <- Validate.nonneg_int(height),
         {:ok, leader} <- Hyperchain.fetch_leaders_schedule_at_height(state, height) do
      format_json(conn, leader)
    end
  end

  @spec validators(Conn.t(), map()) :: Conn.t()
  def validators(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    with {:ok, validators} <-
           Hyperchain.fetch_validators(state, pagination, scope, cursor) do
      WebUtil.render(conn, validators)
    end
  end

  @spec validators_top(Conn.t(), map()) :: Conn.t()
  def validators_top(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor} =
      assigns

    with {:ok, validators} <-
           Hyperchain.fetch_validators_top(state, pagination, cursor) do
      WebUtil.render(conn, validators)
    end
  end

  @spec validator(Conn.t(), map()) :: Conn.t()
  def validator(%Conn{assigns: %{state: state}} = conn, %{"validator_id" => validator_id}) do
    with {:ok, validator} <- Hyperchain.fetch_validator(state, validator_id) |> IO.inspect() do
      format_json(conn, validator)
    end
  end

  @spec validator_delegates(Conn.t(), map()) :: Conn.t()
  def validator_delegates(%Conn{assigns: assigns} = conn, %{
        "validator_id" => validator_id
      }) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    with {:ok, delegates} <-
           Hyperchain.fetch_delegates(state, validator_id, pagination, scope, cursor) do
      WebUtil.render(conn, delegates)
    end
  end

  @spec validator_delegates_top(Conn.t(), map()) :: Conn.t()
  def validator_delegates_top(%Conn{assigns: assigns} = conn, %{
        "validator_id" => validator_id
      }) do
    %{state: state, pagination: pagination, cursor: cursor} =
      assigns

    with {:ok, delegates} <-
           Hyperchain.fetch_delegates_top(state, validator_id, pagination, cursor) do
      WebUtil.render(conn, delegates)
    end
  end
end
