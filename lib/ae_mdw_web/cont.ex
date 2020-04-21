defmodule AeMdwWeb.Continuation do
  alias AeMdw.EtsCache

  @tab AeMdwWeb.Continuation

  ################################################################################

  def table(), do: @tab

  defmodule Cont,
    do: defstruct(stream: nil, offset: nil, user: nil, request: nil)

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

    case EtsCache.get(@tab, cont_key) do
      {%Cont{offset: cont_offset, stream: []}, _tm} when offset >= cont_offset ->
        []

      maybe_cont ->
        stream =
          case maybe_cont do
            {%Cont{offset: ^offset, stream: stream}, _tm} ->
              stream

            _ ->
              stream = stream_maker.(conn.params)
              {_, rem_stream} = StreamSplit.take_and_drop(stream, offset)
              rem_stream
          end

        {res_data, rem_stream} = StreamSplit.take_and_drop(stream, limit)

        new_cont = %Cont{
          offset: offset + limit,
          stream: rem_stream,
          user: user_id,
          request: req_kind
        }

        EtsCache.put(@tab, cont_key, new_cont)

        res_data
    end
  end

end
