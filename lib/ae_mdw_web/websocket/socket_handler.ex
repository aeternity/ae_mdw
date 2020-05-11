defmodule AeWebsocket.Websocket.SocketHandler do
  use Riverside, otp_app: :ae_mdw

  alias AeMdwWeb.Listener
  alias AeMdwWeb.Websocket.EtsManager, as: Ets
  require Ex2ms

  @known_prefixes ["ak_", "ct_", "ok_", "nm_", "cm_", "ch_"]
  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]
  @subs_channel_targets Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)[:subs_channel_targets]
  @subs_target_channels Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)[:subs_target_channels]
  @main Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)[:main]
  @sub Application.fetch_env!(:ae_mdw, AeMdwWeb.Endpoint)[:sub]

  @impl Riverside
  def init(session, state) do
    new_state = Map.put(state, :info, [])
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
      when prefix_key in @known_prefixes and byte_size(rest) > 38 and byte_size(rest) < 60 do
    if target in info do
      deliver_me("already subscribed to: #{target}")
      {:ok, session, state}
    else
      case AeMdw.Validate.id(target) do
        {:ok, id} ->
          {:ok, pid} = Riverside.LocalDelivery.join_channel(id)
          Listener.register(pid)
          Listener.register(self())

          Ets.put(@sub, self(), nil)
          Ets.put(@main, pid, nil)
          Ets.put(@subs_target_channels, {id, self()}, nil)
          Ets.put(@subs_channel_targets, {self(), id}, nil)

          new_state = %{state | info: info ++ [target]}

          deliver_me(new_state.info)
          {:ok, session, new_state}

        {:error, {_, k}} ->
          deliver_me("invalid target: #{k}")
          {:ok, session, state}
      end
    end
  end

  def handle_message(
        %{"op" => "Subscribe", "payload" => "Object", "target" => target},
        session,
        state
      ) do
    deliver_me("invalid target: #{target}")
    {:ok, session, state}
  end

  def handle_message(%{"op" => "Subscribe", "payload" => payload}, session, %{info: info} = state)
      when payload in @known_channels do
    if payload in info do
      deliver_me("already subscribed to: #{payload}")
      {:ok, session, state}
    else
      {:ok, pid} = Riverside.LocalDelivery.join_channel(payload)
      Listener.register(pid)
      Ets.put(:main, pid, nil)

      new_state = %{state | info: info ++ [payload]}
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
    deliver_me("invalid payload: #{payload}")
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
      when prefix_key in @known_prefixes and byte_size(rest) > 38 and byte_size(rest) < 60 do
    if target in info do
      case AeMdw.Validate.id(target) do
        {:ok, id} ->
          pid = self()
          Ets.delete(@subs_target_channels, {id, pid})
          Ets.delete(@subs_channel_targets, {pid, id})

          spec =
            Ex2ms.fun do
              {{^pid, _}, _} -> true
            end

          if Ets.select_count(:subs_channel_targets, spec) == 0, do: Ets.delete(@sub, pid)

          Riverside.LocalDelivery.leave_channel(id)
          new_state = %{state | info: info -- [target]}
          deliver_me(new_state.info)
          {:ok, session, new_state}

        {:error, {_, k}} ->
          deliver_me("invalid target: #{k}")
          {:ok, session, state}
      end
    else
      deliver_me("no subscription for target: #{target}")
      {:ok, session, state}
    end
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => "Object", "target" => target},
        session,
        state
      ) do
    deliver_me("invalid target: #{target}")
    {:ok, session, state}
  end

  def handle_message(
        %{"op" => "Unsubscribe", "payload" => payload},
        session,
        %{info: info} = state
      )
      when payload in @known_channels do
    if payload in info do
      Riverside.LocalDelivery.leave_channel(payload)
      new_state = %{state | info: info -- [payload]}

      deliver_me(new_state.info)
      {:ok, session, new_state}
    else
      deliver_me("no subscription for payload: #{payload}")
      {:ok, session, state}
    end
  end

  def handle_message(%{"op" => "Unsubscribe", "payload" => payload}, session, state) do
    deliver_me("invalid payload: #{payload}")
    {:ok, session, state}
  end

  def handle_message(msg, session, state) do
    deliver_me("invalid subscription: #{inspect(msg)}")
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
