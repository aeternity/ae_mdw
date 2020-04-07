defmodule AeWebsocket.SocketHandler do
  use Riverside, otp_app: :ae_mdw

  @impl Riverside
  def init(session, state) do
    deliver_me("connected")
    new_state = Map.put(state, :info, [])
    {:ok, session, new_state}
  end

  @impl Riverside
  def handle_message(
        %{"op" => "Subscribe", "payload" => "Object", "target" => target},
        session,
        %{info: info} = state
      ) do
    AeMdwWeb.Listener.new_object(target)
    Riverside.LocalDelivery.join_channel(target)
    new_state = %{state | info: info ++ [target]}

    deliver_me(new_state.info)
    {:ok, session, new_state}
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, %{info: info} = state) do
    Riverside.LocalDelivery.join_channel(payload)
    new_state = %{state | info: info ++ [payload]}
    deliver_me(new_state.info)
    {:ok, session, new_state}
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => "Object", "target" => target},
        session,
        %{info: info} = state
      ) do
    AeMdwWeb.Listener.remove_object(target)
    Riverside.LocalDelivery.leave_channel(target)
    new_state = %{state | info: info -- [target]}
    deliver_me(new_state.info)
    {:ok, session, new_state}
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => payload},
        session,
        %{info: info} = state
      ) do
    Riverside.LocalDelivery.leave_channel(payload)
    new_state = %{state | info: info -- [payload]}

    deliver_me(new_state.info)
    {:ok, session, new_state}
  end

  @impl Riverside
  def handle_info(into, session, state) do
    {:ok, session, state}
  end

  @impl Riverside
  def terminate(reason, session, state) do
    :ok
  end
end
