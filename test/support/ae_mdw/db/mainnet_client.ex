defmodule AeMdw.MainnetClient do
  @moduledoc false
  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://mainnet.aeternity.io/mdw/"
  plug Tesla.Middleware.JSON
end
