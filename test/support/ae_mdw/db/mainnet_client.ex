defmodule AeMdw.MainnetClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://mainnet.aeternity.io/mdw/"
  plug Tesla.Middleware.JSON
end
