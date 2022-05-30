defmodule AeMdwWeb.SwaggerForwardV2 do
  @moduledoc """
  Dumb module that forwards plug functions to PhoenixSwagger.Plug.

  This is required because Phoenix doesn't allow the same module to be forwarded
  twice.
  """

  defdelegate init(opts), to: PhoenixSwagger.Plug.SwaggerUI
  defdelegate call(conn, opts), to: PhoenixSwagger.Plug.SwaggerUI
end
