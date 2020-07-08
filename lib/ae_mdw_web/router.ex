defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.DataStreamPlug
  alias AeMdwWeb.NameController, as: NC

  @paginables [
    {["txs"], nil},
    {["names", "auctions"], &NC.stream_plug_hook/1},
    {["names", "active"], &NC.stream_plug_hook/1},
    {["names", "all"], &NC.stream_plug_hook/1}
  ]

  @scopes ["gen", "txi"]

  pipeline :api do
    plug DataStreamPlug, paginables: @paginables, scopes: @scopes
    plug :accepts, ["json"]
  end

  scope "/", AeMdwWeb do
    pipe_through :api

    get "/tx/:hash", TxController, :tx
    get "/txi/:index", TxController, :txi

    get "/txs/count", TxController, :count
    get "/txs/count/:id", TxController, :count_id
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range", TxController, :txs

    get "/name/:id", NameController, :name

    get "/names/auctions", NameController, :all_auctions
    get "/names/pointers/:id", NameController, :pointers
    get "/names/pointees/:id", NameController, :pointees
    get "/names/active", NameController, :active_names
    get "/names/all", NameController, :all_names

    get "/status", UtilController, :status
  end

  scope "/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :ae_mdw,
      swagger_file: "swagger.json",
      disable_validator: true
  end

  def swagger_info do
    %{
      basePath: "/",
      schemes: ["http"],
      consumes: ["application/json"],
      produces: ["application/json"],
      info: %{
        version: "1.0",
        title: "Aeternity Middleware",
        description: "API for [Aeternity Middleware](https://github.com/aeternity/ae_mdw)"
      }
    }
  end
end
