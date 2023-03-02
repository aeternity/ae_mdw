defmodule AeMdwWeb.WebsocketEndpointTest do
  use AeMdwWeb.ConnCase

  test "returns 414 when request is too long" do
    big_query_param = String.duplicate("A", 1500)
    {output, 0} = System.cmd("curl", ["-i", "localhost:4003/websocket?a=#{big_query_param}"])
    assert output =~ "414 Request-URI Too Long"
  end
end
