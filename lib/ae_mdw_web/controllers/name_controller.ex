defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdw.Db.Name
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.DataStreamPlug
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  ##########

  def stream_plug_hook(%Plug.Conn{params: params} = conn) do
    conn
    |> assign(:scope, {:txi, last_txi()..0})
    |> assign(:query, %{})
    |> assign(:offset, ok!(DataStreamPlug.parse_offset(params)))
  end

  ##########

  def name(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> name_reply(conn, Validate.name_id!(ident)) end)

  def pointers(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointers_reply(conn, Validate.name_id!(ident)) end)

  def pointees(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointees_reply(conn, Validate.id!(ident)) end)

  def all_auctions(conn, _req),
    do: Cont.response(conn, &json/2)

  def all_names(conn, _req),
    do: Cont.response(conn, &json/2)

  def active_names(conn, _req),
    do: Cont.response(conn, &json/2)

  ##########

  # scope is used here only for identification of the continuation
  def db_stream(:all_auctions, %{}, _scope),
    do: DBS.Name.all_auctions(:json)

  def db_stream(:all_names, %{}, scope),
    do: DBS.Name.all_names(scope, :json)

  def db_stream(:active_names, %{}, scope),
    do: DBS.Name.active_names(scope, :json)

  ##########

  def name_reply(conn, name_hash) do
    case DBS.map(:backward, :raw, type: :name_claim, name_id: name_hash) |> Enum.take(1) do
      [claim_tx] ->
        [{plain_name, data}] =
          DBS.Name.name_info(claim_tx)
          |> Format.name_info_to_map()
          |> Map.to_list()

        conn |> json(Map.put(data, "name", plain_name))

      [] ->
        conn |> send_error(:not_found, "no such name")
    end
  end

  def pointers_reply(conn, name_hash) do
    case Name.last_name(name_hash) do
      m_name when is_tuple(m_name) ->
        conn |> json(DBS.Name.pointers_info(m_name, :json))

      nil ->
        conn |> send_error(:not_found, "no such name")
    end
  end

  def pointees_reply(conn, pubkey),
    do: conn |> json(DBS.Name.pointees_info(pubkey, :json))

  ##########

  def t() do
    pk =
      <<140, 45, 15, 171, 198, 112, 76, 122, 188, 218, 79, 0, 14, 175, 238, 64, 9, 82, 93, 44,
        169, 176, 237, 27, 115, 221, 101, 211, 5, 168, 169, 235>>

    DBS.map(
      :backward,
      :raw,
      {:or, [["name_claim.account_id": pk], ["name_transfer.recipient_id": pk]]}
    )
  end
end
