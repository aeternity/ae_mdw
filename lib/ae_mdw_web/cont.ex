defmodule AeMdwWeb.Continuation do
  alias AeMdw.EtsCache
  alias AeMdw.Error.Input, as: ErrInput

  import AeMdwWeb.Util

  @tab AeMdwWeb.Continuation

  ################################################################################

  def table(), do: @tab

  def response(%Plug.Conn{path_info: path, assigns: assigns} = conn, ok_fun) do
    mod = conn.private.phoenix_controller
    fun = conn.private.phoenix_action

    %{scope: scope, offset: {limit, page}} = assigns
    offset = (page - 1) * limit

    try do
      params = query_groups(conn.query_string) |> Map.drop(["limit", "page"])

      case response_data({mod, fun, params, scope, offset}, limit) do
        {:ok, data, has_cont?} ->
          next = (has_cont? && next_link(path, scope, params, limit, page)) || nil
          ok_fun.(conn, %{next: next, data: data})

        {:error, reason} ->
          send_error(conn, :bad_request, error_msg(reason))
      end
    rescue
      err in [ErrInput] ->
        send_error(conn, :bad_request, error_msg(err))
    end
  end

  def response_data({mod, fun, params, scope, offset} = cont_key, limit) do
    make_key = fn new_offset -> {mod, fun, params, scope, new_offset} end

    case EtsCache.get(@tab, cont_key) do
      # beginning
      nil when offset == 0 ->
        init_stream = mod.db_stream(fun, params, scope)
        {data, rem_stream} = StreamSplit.take_and_drop(init_stream, limit)
        has_cont? = rem_stream != []
        EtsCache.put(@tab, cont_key, init_stream)
        has_cont? && EtsCache.put(@tab, make_key.(limit), rem_stream)
        {:ok, data, has_cont?}

      # middle
      {stream, _tm} ->
        {data, rem_stream} = StreamSplit.take_and_drop(stream, limit)
        has_cont? = rem_stream != []
        has_cont? && EtsCache.put(@tab, make_key.(offset + limit), rem_stream)
        {:ok, data, has_cont?}

      nil ->
        case :ets.prev(@tab, make_key.(<<>>)) do
          # end
          {^mod, ^fun, ^params, ^scope, last_offset} when last_offset < offset ->
            {:ok, [], false}

          _ ->
            # never seen req with non-zero offset -> Denial Of Service attempt
            {:error, :dos}
        end
    end
  end

  defp error_msg(%ErrInput{message: msg}), do: msg
  defp error_msg(:dos), do: "random access not supported"
end
