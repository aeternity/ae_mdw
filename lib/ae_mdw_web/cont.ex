defmodule AeMdwWeb.Continuation do
  require Ex2ms

  @cont_tab AeMdwWeb.Continuation

  ################################################################################

  def table(),
    do: AeMdwWeb.Continuation

  defmodule Cont,
    do: defstruct [stream: nil, offset: nil, user: nil, request: nil]


  # until we can modify frontend, we need to use this heuristics...
  # also, different tabs of the same user use the same continuation - not great
  # (... and there's some axios client which has very brief user-agent - not great)
  def infer_user(%Plug.Conn{} = conn),
    do: {conn.assigns.peer_ip, conn.assigns.browser_info}

  def request_kind(%Plug.Conn{assigns: %{limit_page: {_, _}}} = conn),
    do: {conn.request_path, Map.drop(conn.params, ["limit", "page"])}

  def key(user, req_kind),
    do: :crypto.hash(:sha256, :erlang.term_to_binary({user, req_kind}))


  def response(%Plug.Conn{} = conn, stream_maker) do
    {limit, page} = conn.assigns.limit_page
    offset = (page - 1) * limit
    user_id = infer_user(conn)
    req_kind = request_kind(conn)
    cont_key = key(user_id, req_kind)

    case :ets.lookup(@cont_tab, cont_key) do
      [{_, %Cont{offset: cont_offset, stream: []}, _tm}] when offset >= cont_offset ->
        []

      maybe_cont ->
        stream =
          case maybe_cont do
            [{_, %Cont{offset: ^offset, stream: stream}, _tm}] ->
              stream
            _ ->
              stream = stream_maker.(conn.params)
              {_, rem_stream} = StreamSplit.take_and_drop(stream, offset)
              rem_stream
          end

        {res_data, rem_stream} = StreamSplit.take_and_drop(stream, limit)
        new_cont = %Cont{offset: offset + limit,
                         stream: rem_stream,
                         user: user_id,
                         request: req_kind}

        :ets.insert(@cont_tab, {cont_key, new_cont, time()})

        res_data
    end
  end


  def purge(max_age_msecs) do
    boundary = time() - max_age_msecs
    del_spec = Ex2ms.fun do {_, _, time} -> time < ^boundary end
    :ets.select_delete(@cont_tab, del_spec)
  end

  defp time(),
    do: :os.system_time(:millisecond)

end
