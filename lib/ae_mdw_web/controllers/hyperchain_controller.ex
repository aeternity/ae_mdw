defmodule AeMdwWeb.HyperchainController do
  use AeMdwWeb, :controller

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Hyperchain
  alias AeMdw.Node
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util, as: WebUtil
  alias AeMdwWeb.Plugs.HyperchainPlug
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  plug(HyperchainPlug)
  plug(PaginatedPlug, order_by: ~w(expiration activation deactivation name)a)
  action_fallback(FallbackController)

  @spec leaders(Conn.t(), map()) :: Conn.t()
  def leaders(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    with {:ok, deserialized_scope} <- deserialize_leaders_scope(scope) do
      state
      |> Hyperchain.fetch_leaders(pagination, deserialized_scope, cursor)
      |> then(&WebUtil.render(conn, &1))
    end
  end

  @spec leader_by_height(Conn.t(), map()) :: Conn.t()
  def leader_by_height(%Conn{assigns: %{state: state}} = conn, %{"height" => height}) do
    with {:ok, height} <- Validate.nonneg_int(height),
         {:ok, leader} <- Hyperchain.fetch_leader_by_height(state, height) do
      format_json(conn, leader)
    end
  end

  def epochs(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    state
    |> Hyperchain.fetch_epochs(pagination, scope, cursor)
    |> then(&WebUtil.render(conn, &1))
  end

  def validator(%Conn{assigns: %{state: state}} = conn, %{"validator_id" => validator_id}) do
    with {:ok, validator} <- Hyperchain.fetch_validator(state, validator_id) |> IO.inspect() do
      format_json(conn, validator)
    end
  end

  defp deserialize_leaders_scope(scope) do
    case scope do
      nil ->
        {:ok, nil}

      {:gen, first_gen..last_gen//_step} ->
        {:ok, {first_gen, last_gen}}

      {:epoch, first_epoch..last_epoch//_step} ->
        with {:ok, epoch_length} = Node.epoch_length(last_epoch),
             {:ok, first_gen} <- Node.epoch_start_height(first_epoch),
             {:ok, last_gen} <- Node.epoch_start_height(last_epoch) do
          {:ok, {first_gen, last_gen + epoch_length - 1}}
        else
          {:error, error} ->
            {:error, ErrInput.Scope.exception(value: error)}
        end
    end
  end
end
