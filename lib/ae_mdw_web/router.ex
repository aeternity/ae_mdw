defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.DataStreamPlug
  alias AeMdwWeb.NameController, as: NC

  @paginables [
    {["txs"], nil},
    {["blocks"], &AeMdwWeb.BlockController.stream_plug_hook/1},
    {["names", "auctions"], &NC.stream_plug_hook/1},
    {["names", "inactive"], &NC.stream_plug_hook/1},
    {["names", "active"], &NC.stream_plug_hook/1},
    {["names"], &NC.stream_plug_hook/1}
  ]

  @scopes ["gen", "txi"]

  pipeline :api do
    plug DataStreamPlug, paginables: @paginables, scopes: @scopes
    plug :accepts, ["json"]
  end

  scope "/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :ae_mdw,
      swagger_file: "swagger.json",
      disable_validator: true
  end

  scope "/", AeMdwWeb do
    pipe_through :api

    get "/block/:hash", BlockController, :block
    get "/blocki/:kbi", BlockController, :blocki
    get "/blocki/:kbi/:mbi", BlockController, :blocki

    # for continuation link only
    get "/blocks/gen/:range", BlockController, :blocks
    # by default no scope_type needed
    get "/blocks/:range_or_dir", BlockController, :blocks

    get "/tx/:hash", TxController, :tx
    get "/txi/:index", TxController, :txi

    get "/txs/count", TxController, :count
    get "/txs/count/:id", TxController, :count_id
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range", TxController, :txs

    get "/name/:id", NameController, :name
    get "/name/pointers/:id", NameController, :pointers
    get "/name/pointees/:id", NameController, :pointees

    get "/names/auctions", NameController, :auctions
    get "/names/auctions/:scope_type/:range", NameController, :auctions

    get "/names/inactive", NameController, :inactive_names
    get "/names/inactive/:scope_type/:range", NameController, :inactive_names

    get "/names/active", NameController, :active_names
    get "/names/active/:scope_type/:range", NameController, :active_names

    get "/names", NameController, :names
    get "/names/:scope_type/:range", NameController, :names

    get "/status", UtilController, :status

    match :*, "/*path", UtilController, :no_route
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
