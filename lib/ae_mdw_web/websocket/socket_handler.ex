defmodule AeWebsocket.Websocket.SocketHandler do
  use Riverside, otp_app: :ae_mdw

  alias AeMdwWeb.Websocket.Listener
  alias AeMdwWeb.Util

  require Ex2ms

  @subs_main :subs_main
  @subs_pids :subs_pids
  @subs_channel_targets :subs_channel_targets
  @subs_target_channels :subs_target_channels
  @known_prefixes ["ak_", "ct_", "ok_", "nm_", "cm_", "ch_"]
  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]

  @impl Riverside
  def init(session, state) do
    new_state = Map.put(state, :info, MapSet.new())
    {:ok, session, new_state}
  end

  @impl Riverside
  def handle_message(
        %{
          "op" => "Subscribe",
          "payload" => "Object",
          "target" => <<prefix_key::binary-size(3), rest::binary>> = target
        },
        session,
        %{info: info} = state
      )
      when prefix_key in @known_prefixes and byte_size(rest) >= 38 and byte_size(rest) <= 60 do
    if MapSet.member?(info, target) do
      Util.concat("already subscribed to target", target) |> deliver_me()
      {:ok, session, state}
    else
      case AeMdw.Validate.id(target) do
        {:ok, id} ->
          {:ok, pid} = Riverside.LocalDelivery.join_channel(id)
          Listener.register(pid)
          Listener.register(self())

          :ets.insert(@subs_pids, {self(), nil})
          :ets.insert(@subs_main, {pid, nil})
          :ets.insert(@subs_target_channels, {{id, self()}, nil})
          :ets.insert(@subs_channel_targets, {{self(), id}, nil})

          new_state = %{state | info: MapSet.put(info, target)}

          deliver_me(new_state.info)
          {:ok, session, new_state}

        {:error, {_, k}} ->
          Util.concat("invalid target", k) |> deliver_me()
          {:ok, session, state}
      end
    end
  end

  def handle_message(
        %{"op" => "Subscribe", "payload" => "Object", "target" => target},
        session,
        state
      ) do
    Util.concat("invalid target", target) |> deliver_me()
    {:ok, session, state}
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, %{info: info} = state)
      when payload in @known_channels do
    if MapSet.member?(info, payload) do
      Util.concat("already subscribed to", payload) |> deliver_me()
      {:ok, session, state}
    else
      {:ok, pid} = Riverside.LocalDelivery.join_channel(payload)
      Listener.register(pid)
      :ets.insert(@subs_main, {pid, nil})

      new_state = %{state | info: MapSet.put(info, payload)}
      deliver_me(new_state.info)
      {:ok, session, new_state}
    end
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, state)
      when payload == "Object" do
    deliver_me("requires target")
    {:ok, session, state}
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, state) do
    Util.concat("invalid payload", payload) |> deliver_me()
    {:ok, session, state}
  end

  def handle_message(
        %{
          "op" => "Unsubscribe",
          "payload" => "Object",
          "target" => <<prefix_key::binary-size(3), rest::binary>> = target
        },
        session,
        %{info: info} = state
      )
      when prefix_key in @known_prefixes and byte_size(rest) >= 38 and byte_size(rest) <= 60 do
    if MapSet.member?(info, target) do
      case AeMdw.Validate.id(target) do
        {:ok, id} ->
          pid = self()
          :ets.delete(@subs_target_channels, {id, pid})
          :ets.delete(@subs_channel_targets, {pid, id})

          spec =
            Ex2ms.fun do
              {{^pid, _}, _} -> true
            end

          if :ets.select_count(@subs_channel_targets, spec) == 0, do: :ets.delete(@subs_pids, pid)

          Riverside.LocalDelivery.leave_channel(id)
          new_state = %{state | info: MapSet.delete(info, target)}
          deliver_me(new_state.info)
          {:ok, session, new_state}

        {:error, {_, k}} ->
          deliver_me("invalid target: #{k}")
          {:ok, session, state}
      end
    else
      Util.concat("no subscription for target", target) |> deliver_me()
      {:ok, session, state}
    end
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => "Object", "target" => target},
        session,
        state
      ) do
    Util.concat("invalid target", target) |> deliver_me()
    {:ok, session, state}
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => payload},
        session,
        %{info: info} = state
      )
      when payload in @known_channels do
    if MapSet.member?(info, payload) do
      Riverside.LocalDelivery.leave_channel(payload)
      new_state = %{state | info: MapSet.delete(info, payload)}

      deliver_me(new_state.info)
      {:ok, session, new_state}
    else
      Util.concat("no subscription for payload", payload) |> deliver_me()
      {:ok, session, state}
    end
  end

  def handle_message(%{"op" => "Unsubscribe", "payload" => payload}, session, state) do
    Util.concat("invalid payload", payload) |> deliver_me()
    {:ok, session, state}
  end

  def handle_message(msg, session, state) do
    Util.concat("invalid subscription", msg) |> deliver_me()
    {:ok, session, state}
  end

  @impl Riverside
  def handle_info(_into, session, state) do
    {:ok, session, state}
  end

  @impl Riverside
  def terminate(_reason, _session, _state) do
    :ok
  end
end
