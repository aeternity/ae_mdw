defmodule AeMdwWeb.WebsocketEndpointTest do
  use AeMdwWeb.ConnCase

  import ExUnit.CaptureLog

  test "returns 414 when request is too long" do
    fun = fn ->
      big_query_param = String.duplicate("A", 1024 + 1)
      {_output, 0} = System.cmd("curl", ["-i", "localhost:4003/websocket?a=#{big_query_param}"])
    end

    assert capture_log(fun) =~ "(Bandit.HTTPError) Request URI is too long"
  end
end
