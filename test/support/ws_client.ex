defmodule Support.WsClient do
  # credo:disable-for-this-file
  use WebSockex

  @mock_hash "th_XCzs29JhAh7Jpd5fypNi42Kszc4eVYEadw62cNBc7qBHajhD7"
  @mock_hash_tx_mdw "th_VyepHVU43zbytTihQprS689bbq9pYcHkW9iw7GZnUGmaf8N5o"
  @mock_hash_obj_mdw "th_2KYycJjNrL4htFhwCVrKnx3nazdzZ3Vu4XPRhoqMpvTB5SGK4Q"

  def start_link(url), do: WebSockex.start(url, __MODULE__, %{subs: []})

  def delete_subscriptions(client), do: Process.send(client, {:delete_list, :subs}, [:noconnect])
  def delete_objects(client), do: Process.send(client, {:delete_list, :objs}, [:noconnect])
  def delete_transactions(client), do: Process.send(client, {:delete_list, :txs}, [:noconnect])

  def subscribe(client, payload, source) when is_atom(payload) do
    request = %{payload: to_subs(payload), op: "Subscribe", source: source}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def subscribe(client, key, source) when is_binary(key) do
    request = %{payload: "Object", op: "Subscribe", target: key, source: source}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def subscribe(client, payload) when is_atom(payload) do
    request = %{payload: to_subs(payload), op: "Subscribe"}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def subscribe(client, key) when is_binary(key) do
    request = %{payload: "Object", op: "Subscribe", target: key}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def unsubscribe(client, payload, source) when is_atom(payload) do
    request = %{payload: to_subs(payload), op: "Unsubscribe", source: source}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def unsubscribe(client, key, source) when is_binary(key) do
    request = %{payload: "Object", op: "Unsubscribe", target: key, source: source}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def unsubscribe(client, payload) when is_atom(payload) do
    request = %{payload: to_subs(payload), op: "Unsubscribe"}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def unsubscribe(client, key) when is_binary(key) do
    request = %{payload: "Object", op: "Unsubscribe", target: key}
    WebSockex.send_frame(client, {:text, Jason.encode!(request)})
  end

  def handle_frame({:text, msg}, state) do
    new_state =
      case Jason.decode!(msg) do
        %{"subscription" => "MicroBlocks"} = msg ->
          state
          |> Map.put(:mb, msg)
          |> Map.update(:msgs, [msg], &(&1 ++ [msg]))

        %{"subscription" => "KeyBlocks"} = msg ->
          state
          |> Map.put(:kb, msg)
          |> Map.update(:msgs, [msg], &(&1 ++ [msg]))

        %{"subscription" => "Transactions", "payload" => %{"hash" => @mock_hash}} = msg ->
          Map.put(state, :tx, msg)

        %{"subscription" => "Transactions", "payload" => %{"hash" => @mock_hash_tx_mdw}} = msg ->
          Map.put(state, :tx, msg)

        %{"subscription" => "Transactions"} = msg ->
          Map.update(state, :txs, [msg], fn list -> list ++ [msg] end)

        %{"subscription" => "Object", "payload" => %{"hash" => @mock_hash}} = msg ->
          Map.put(state, :obj, msg)

        %{"subscription" => "Object", "payload" => %{"hash" => @mock_hash_obj_mdw}} = msg ->
          Map.put(state, :obj, msg)

        %{"subscription" => "Object"} = msg ->
          Map.update(state, :objs, [msg], fn list -> list ++ [msg] end)

        subs when is_list(subs) ->
          Map.put(state, :subs, subs)

        msg ->
          Map.put(state, :error, msg)
      end

    {:ok, new_state}
  end

  def handle_info({:delete_list, list_key}, state) do
    {:ok, Map.put(state, list_key, [])}
  end

  def handle_info({request, from}, state) do
    data = Map.get(state, request)
    send(from, data)
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    super(disconnect_map, state)
  end

  defp to_subs(subs) when is_atom(subs), do: "#{subs}" |> Macro.camelize()
end
