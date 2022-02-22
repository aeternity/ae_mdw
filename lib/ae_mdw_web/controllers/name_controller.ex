defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.AuctionBids
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdw.Db.Name
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.SwaggerParameters
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  import AeMdwWeb.Util
  import AeMdw.Util

  plug PaginatedPlug,
       [order_by: ~w(expiration name)a]
       when action in ~w(active_names inactive_names names auctions search search_v1)a

  @lifecycles_map %{
    "active" => :active,
    "inactive" => :inactive,
    "auction" => :auction
  }
  @lifecycles Map.keys(@lifecycles_map)

  @spec auction(Conn.t(), map()) :: Conn.t()
  def auction(conn, %{"id" => ident} = params),
    do:
      handle_input(conn, fn ->
        auction_reply(conn, Validate.plain_name!(ident), expand?(params))
      end)

  @spec pointers(Conn.t(), map()) :: Conn.t()
  def pointers(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointers_reply(conn, Validate.plain_name!(ident)) end)

  @spec pointees(Conn.t(), map()) :: Conn.t()
  def pointees(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointees_reply(conn, Validate.name_id!(ident)) end)

  @spec name(Conn.t(), map()) :: Conn.t()
  def name(conn, %{"id" => ident} = params),
    do:
      handle_input(conn, fn ->
        name_reply(conn, Validate.plain_name!(ident), expand?(params))
      end)

  @spec owned_by(Conn.t(), map()) :: Conn.t()
  def owned_by(conn, %{"id" => owner} = params),
    do:
      handle_input(conn, fn ->
        active? = Map.get(params, "active", "true") == "true"
        owned_by_reply(conn, Validate.id!(owner, [:account_pubkey]), expand?(params), active?)
      end)

  @spec auctions(Conn.t(), map()) :: Conn.t()
  def auctions(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: pagination, cursor: cursor, expand?: expand?, order_by: order_by} = assigns

    {prev_cursor, auction_bids, next_cursor} =
      AuctionBids.fetch_auctions(pagination, order_by, cursor, expand?)

    Util.paginate(conn, prev_cursor, auction_bids, next_cursor)
  end

  @spec inactive_names(Conn.t(), map()) :: Conn.t()
  def inactive_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_inactive_names(pagination, scope, order_by, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec active_names(Conn.t(), map()) :: Conn.t()
  def active_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_active_names(pagination, scope, order_by, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec names(Conn.t(), map()) :: Conn.t()
  def names(%Conn{assigns: assigns, query_params: query} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_names(pagination, scope, order_by, query, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec search_v1(Conn.t(), map()) :: Conn.t()
  def search_v1(conn, %{"prefix" => prefix}) do
    handle_input(conn, fn ->
      params = Map.put(query_groups(conn.query_string), "prefix", [prefix])
      json(conn, Enum.to_list(do_prefix_stream(validate_search_params!(params), expand?(params))))
    end)
  end

  @spec search(Conn.t(), map()) :: Conn.t()
  def search(%Conn{assigns: assigns, query_string: query_string} = conn, %{"prefix" => prefix}) do
    lifecycles =
      query_string
      |> URI.query_decoder()
      |> Enum.filter(&match?({"only", lifecycle} when lifecycle in @lifecycles, &1))
      |> Enum.map(fn {"only", lifecycle} -> Map.fetch!(@lifecycles_map, lifecycle) end)
      |> Enum.uniq()

    %{pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, names, next_cursor} =
      Names.search_names(lifecycles, prefix, pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, names, next_cursor)
  end

  ##########

  defp name_reply(conn, plain_name, expand?) do
    case Name.locate(plain_name) do
      {info, source} -> json(conn, Format.to_map(info, source, expand?))
      nil -> raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointers_reply(conn, plain_name) do
    case Name.locate(plain_name) do
      {m_name, Model.ActiveName} ->
        json(conn, Format.map_raw_values(Name.pointers(m_name), &Format.to_json/1))

      {_, Model.InactiveName} ->
        raise ErrInput.Expired, value: plain_name

      _no_match? ->
        raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointees_reply(conn, pubkey) do
    {active, inactive} = Name.pointees(pubkey)

    json(conn, %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    })
  end

  defp auction_reply(conn, plain_name, expand?) do
    map_some(
      Name.locate_bid(plain_name),
      &json(conn, Format.to_map(&1, Model.AuctionBid, expand?))
    ) ||
      raise ErrInput.NotFound, value: plain_name
  end

  defp owned_by_reply(conn, owner_pk, expand?, active?) do
    query_res = Name.owned_by(owner_pk, active?)

    jsons = fn plains, source, locator ->
      for plain <- plains, reduce: [] do
        acc ->
          case locator.(plain) do
            {info, ^source} -> [Format.to_map(info, source, expand?) | acc]
            _not_found? -> acc
          end
      end
    end

    if active? do
      names = jsons.(query_res.names, Model.ActiveName, &Name.locate/1)

      top_bids =
        jsons.(
          query_res.top_bids,
          Model.AuctionBid,
          &map_some(Name.locate_bid(&1), fn x -> {x, Model.AuctionBid} end)
        )

      json(conn, %{"active" => names, "top_bid" => top_bids})
    else
      names = jsons.(query_res.names, Model.InactiveName, &Name.locate/1)

      json(conn, %{"inactive" => names})
    end
  end

  ##########

  defp do_prefix_stream({prefix, lifecycles}, expand?) do
    streams = Enum.map(lifecycles, &prefix_stream(&1, prefix, expand?))

    case streams do
      [single] -> single
      [_ | _] -> merged_stream(streams, & &1["name"], :forward)
    end
  end

  ##########

  defp validate_search_params!(params),
    do: do_validate_search_params!(Map.delete(params, "expand"))

  defp do_validate_search_params!(%{"prefix" => [prefix], "only" => [_ | _] = lifecycles}) do
    {prefix,
     lifecycles
     |> Enum.map(fn
       "auction" -> :auction
       "active" -> :active
       "inactive" -> :inactive
       invalid -> raise ErrInput.Query, value: "name lifecycle #{invalid}"
     end)
     |> Enum.uniq()}
  end

  defp do_validate_search_params!(%{"prefix" => [prefix]}),
    do: {prefix, [:auction, :active, :inactive]}

  ##########

  defp prefix_stream(:auction, prefix, expand?),
    do:
      DBS.Name.auction_prefix_resource(
        prefix,
        :forward,
        &Format.to_map(&1, Model.AuctionBid, expand?)
      )

  defp prefix_stream(:active, prefix, expand?),
    do:
      DBS.Name.prefix_resource(
        Model.ActiveName,
        prefix,
        :forward,
        &Format.to_map(&1, Model.ActiveName, expand?)
      )

  defp prefix_stream(:inactive, prefix, expand?),
    do:
      DBS.Name.prefix_resource(
        Model.InactiveName,
        prefix,
        :forward,
        &Format.to_map(&1, Model.InactiveName, expand?)
      )

  ##########
  @spec swagger_definitions() :: term()
  def swagger_definitions do
    %{
      Pointers:
        swagger_schema do
          title("Pointers")
          description("Schema for pointers")

          properties do
            account_pubkey(:string, "The account public key")
          end

          example(%{
            account_pubkey: "ak_2cJokSy6YHfoE9zuXMygYPkGb1NkrHsXqRUAAj3Y8jD7LdfnU7"
          })
        end,
      Ownership:
        swagger_schema do
          title("Ownership")
          description("Schema for ownership")

          properties do
            current(:string, "The current owner")
            original(:string, "The original account that claimed the name")
          end

          example(%{
            current: "ak_2rGuHcjycoZgzhAY3Jexo6e1scj3JRCZu2gkrSxGEMf2SktE3A",
            original: "ak_2ruXgsLy9jMwEqsgyQgEsxw8chYDfv2QyBfCsR6qtpQYkektWB"
          })
        end,
      Info:
        swagger_schema do
          title("Info")
          description("Schema for info")

          properties do
            active_from(:integer, "The height from which the name becomes active")
            auction_timeout(:integer, "The auction expiry time", nullable: true)
            claims(:array, "The txs indexes when the name has been claimed")
            expire_height(:integer, "The expiry height")
            ownership(Schema.ref(:Ownership), "The owner/owners of the name")
            pointers(Schema.ref(:Pointers), "The pointers")
            revoke(:integer, "The transaction index when the name is revoked", nullable: true)
            transfers(:array, "The txs indexes when the name has been transferred")
            updates(:array, "The txs indexes when the name has been updated")
          end

          example(%{
            active_from: 307_967,
            auction_timeout: nil,
            claims: [
              15_173_653,
              15_173_471,
              15_173_219,
              15_172_614,
              15_141_698,
              15_141_069,
              15_130_223,
              15_123_418,
              15_111_033,
              15_109_837,
              15_109_343,
              15_109_065,
              15_108_088,
              15_105_072
            ],
            expire_height: 357_967,
            ownership: %{
              current: "ak_sWEHSSG5jKNAXYmJgzHsUXgrd5HajBPRcnn72RJLpZ3h5GFUf",
              original: "ak_sWEHSSG5jKNAXYmJgzHsUXgrd5HajBPRcnn72RJLpZ3h5GFUf"
            },
            pointers: %{},
            revoke: nil,
            transfers: [],
            updates: []
          })
        end,
      InfoAuctions:
        swagger_schema do
          title("Info auctions")
          description("Schema for info auctions")

          properties do
            auction_end(:integer, "The key height when the name auction ends")
            bids(:array, "The bids")
            last_bid(Schema.ref(:TxResponse), "The last bid transaction")
          end

          example(%{
            auction_end: 337_254,
            bids: [
              15_174_500,
              13_420_324,
              12_162_516,
              10_084_545,
              10_062_546,
              7_880_893,
              7_878_252,
              5_961_322,
              5_931_405,
              5_583_812,
              4_801_808
            ],
            last_bid: %{
              block_hash: "mh_AMe7YRgxoc6cCy1iDx2QZxeGb9kkFG9Ukfj8dF7srttr8RfGQ",
              block_height: 307_494,
              hash: "th_27bjCRSBgXkzWcYqjwJ6CHweyXVft3KeM7e1Suv6sm3LiPsdRx",
              micro_index: 19,
              micro_time: 1_598_932_662_983,
              signatures: [
                "sg_W2HJKB5ygvL2X6tcdKx8uP3kd2rFJZhTbDPCt4REG1isqopwXdsRLxxiizB7P8WHbY8tkwRkDR2CjnxQNTdMuyvBw6RqN"
              ],
              tx: %{
                account_id: "ak_e1PYvFVDZAXMiNC7ikkhaQsKpXzYi6XeiWwY6apAT2j4Ujjoo",
                fee: 16_320_000_000_000,
                name: "b.chain",
                name_fee: 1_100_000_000_000_000_000_000,
                name_id: "nm_26sSGSJdjgNW72dGyctY3PPeFuYtAXd8ySEJTpPK5r5fv2i3sW",
                name_salt: 0,
                nonce: 11,
                type: "NameClaimTx",
                version: 2
              },
              tx_index: 15_174_500
            }
          })
        end,
      NameByIdResponse:
        swagger_schema do
          title("Response for name or encoded hash")
          description("Response schema for name or encoded hash")

          properties do
            active(:boolean, "The active status", required: true)
            hash(:string, "The hash of the name", required: true)
            info(Schema.ref(:Info), "The info", required: true)
            name(:string, "The name", required: true)
            previous(Schema.array(:Info), "The previous owners", required: true)
            status(:string, "The status", required: true)
          end

          example(%{
            active: true,
            hash: "nm_S4ofw6861biSJrXgHuJPo7VotLbrY8P9ngTLvgrRwbDEA3svc",
            info: %{
              active_from: 307_967,
              auction_timeout: nil,
              claims: [
                15_173_653,
                15_173_471,
                15_173_219,
                15_172_614,
                15_141_698,
                15_141_069,
                15_130_223,
                15_123_418,
                15_111_033,
                15_109_837,
                15_109_343,
                15_109_065,
                15_108_088,
                15_105_072
              ],
              expire_height: 357_967,
              ownership: %{
                current: "ak_sWEHSSG5jKNAXYmJgzHsUXgrd5HajBPRcnn72RJLpZ3h5GFUf",
                original: "ak_sWEHSSG5jKNAXYmJgzHsUXgrd5HajBPRcnn72RJLpZ3h5GFUf"
              },
              pointers: %{},
              revoke: nil,
              transfers: [],
              updates: []
            },
            name: "aeternity.chain",
            previous: [
              %{
                active_from: 162_197,
                auction_timeout: nil,
                claims: [4_712_046, 4_711_222, 4_708_228, 4_693_879, 4_693_568, 4_678_533],
                expire_height: 304_439,
                ownership: %{
                  current: "ak_2rGuHcjycoZgzhAY3Jexo6e1scj3JRCZu2gkrSxGEMf2SktE3A",
                  original: "ak_2ruXgsLy9jMwEqsgyQgEsxw8chYDfv2QyBfCsR6qtpQYkektWB"
                },
                pointers: %{
                  account_pubkey: "ak_2cJokSy6YHfoE9zuXMygYPkGb1NkrHsXqRUAAj3Y8jD7LdfnU7"
                },
                revoke: nil,
                transfers: [8_778_162],
                updates: [11_110_443, 10_074_212, 10_074_008, 8_322_927, 7_794_392]
              }
            ],
            status: "name"
          })
        end,
      NameAuctions:
        swagger_schema do
          title("Name auctions")
          description("Schema for name auctions")

          properties do
            active(:boolean, "The name auction status", required: true)
            hash(:string, "The hash of the name", required: true)
            info(Schema.ref(:InfoAuctions), "The info", required: true)
            name(:string, "The name", required: true)
            previous(Schema.array(:Info), "The previous owners", required: true)
            status(:string, "The name status", required: true)
          end

          example(%{
            active: false,
            hash: "nm_26sSGSJdjgNW72dGyctY3PPeFuYtAXd8ySEJTpPK5r5fv2i3sW",
            info: %{
              auction_end: 337_254,
              bids: [
                15_174_500,
                13_420_324,
                12_162_516,
                10_084_545,
                10_062_546,
                7_880_893,
                7_878_252,
                5_961_322,
                5_931_405,
                5_583_812,
                4_801_808
              ],
              last_bid: %{
                block_hash: "mh_AMe7YRgxoc6cCy1iDx2QZxeGb9kkFG9Ukfj8dF7srttr8RfGQ",
                block_height: 307_494,
                hash: "th_27bjCRSBgXkzWcYqjwJ6CHweyXVft3KeM7e1Suv6sm3LiPsdRx",
                micro_index: 19,
                micro_time: 1_598_932_662_983,
                signatures: [
                  "sg_W2HJKB5ygvL2X6tcdKx8uP3kd2rFJZhTbDPCt4REG1isqopwXdsRLxxiizB7P8WHbY8tkwRkDR2CjnxQNTdMuyvBw6RqN"
                ],
                tx: %{
                  account_id: "ak_e1PYvFVDZAXMiNC7ikkhaQsKpXzYi6XeiWwY6apAT2j4Ujjoo",
                  fee: 16_320_000_000_000,
                  name: "b.chain",
                  name_fee: 1_100_000_000_000_000_000_000,
                  name_id: "nm_26sSGSJdjgNW72dGyctY3PPeFuYtAXd8ySEJTpPK5r5fv2i3sW",
                  name_salt: 0,
                  nonce: 11,
                  type: "NameClaimTx",
                  version: 2
                },
                tx_index: 15_174_500
              }
            },
            name: "b.chain",
            previous: [],
            status: "auction"
          })
        end,
      NamesAuctionsResponse:
        swagger_schema do
          title("Names auctions")
          description("Schema for names auctions")

          properties do
            data(Schema.array(:NameAuctions), "The data for the names auctions", required: true)
            next(:string, "The continuation link", required: true)
          end
        end,
      NamesResponse:
        swagger_schema do
          title("Names")
          description("Response schema for names")

          properties do
            data(Schema.array(:NameByIdResponse), "The data for the names", required: true)
            next(:string, "The continuation link", required: true)
          end

          example(%{
            data: [
              %{
                active: true,
                hash: "nm_2YmgvoUhVua9wEYGpMj9ybctbQXHPbY9Ppu4CoKoUm8jjFfcsc",
                info: %{
                  active_from: 163_282,
                  auction_timeout: nil,
                  claims: [4_793_600, 4_792_073, 4_780_558, 4_750_560],
                  expire_height: 362_026,
                  ownership: %{
                    current: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN",
                    original: "ak_pMwUuWtqDoPxVtyAmWT45JvbCF2pGTmbCMB4U5yQHi37XF9is"
                  },
                  pointers: %{
                    account_pubkey: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
                  },
                  revoke: nil,
                  transfers: [11_861_568, 11_860_267],
                  updates: [
                    15_509_041,
                    15_472_510,
                    15_436_683,
                    15_399_850,
                    15_363_107,
                    15_327_260,
                    15_292_125,
                    15_255_201,
                    15_218_294,
                    15_182_623,
                    15_145_666,
                    15_106_041,
                    15_103_138,
                    15_102_422,
                    15_034_493,
                    14_998_378,
                    14_962_285,
                    14_926_110,
                    14_889_735,
                    14_853_605,
                    14_816_113,
                    14_780_302,
                    14_734_948,
                    14_697_934,
                    14_660_004,
                    14_622_742,
                    14_585_275,
                    14_549_202,
                    14_512_586,
                    14_475_599,
                    14_433_402,
                    14_395_593,
                    14_359_214,
                    14_322_121,
                    14_275_361,
                    14_237_928,
                    14_197_055,
                    14_158_176,
                    14_118_957,
                    14_083_790,
                    14_047_637,
                    14_007_331,
                    13_968_434,
                    13_929_634,
                    13_888_411,
                    13_852_034,
                    13_729_934,
                    13_692_516,
                    13_655_299,
                    13_621_141,
                    13_585_850,
                    13_549_286,
                    13_517_014,
                    13_478_966,
                    13_119_079,
                    13_119_035,
                    13_119_002,
                    13_118_969,
                    13_118_936,
                    12_758_156,
                    12_758_112,
                    12_432_743,
                    12_432_718,
                    12_432_693,
                    12_432_668,
                    12_432_643,
                    12_077_832,
                    10_477_629,
                    7_255_087,
                    4_831_909
                  ]
                },
                name: "trustwallet.chain",
                previous: [],
                status: "name"
              }
            ],
            next: "names/gen/312032-0?limit=1&page=2"
          })
        end,
      PointersResponse:
        swagger_schema do
          title("Pointers")
          description("Response schema for pointers")

          properties do
            account_pubkey(:string, "The account public key")
          end

          example(%{account_pubkey: "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"})
        end,
      Update:
        swagger_schema do
          title("Update")
          description("Response schema for update")

          properties do
            block_height(:integer, "The block height")
            micro_index(:integer, "The micro block index")
            tx_index(:integer, "The transaction index")
          end

          example(%{block_height: 279_558, micro_index: 51, tx_index: 12_942_695})
        end,
      ActiveInactive:
        swagger_schema do
          title("Active/Inactive")
          description("Schema for active/inactive")

          properties do
            active_from(:integer, "The height when the name become active")
            expire_height(:integer, "The height when the name expire")
            name(:string, "The name")
            update(Schema.ref(:Update), "The update info")
          end

          example(%{
            active_from: 279_555,
            expire_height: 329_558,
            name: "wwwbeaconoidcom.chain",
            update: %{block_height: 279_558, micro_index: 51, tx_index: 12_942_695}
          })
        end,
      ActivesInactives:
        swagger_schema do
          title("Actives/Inactives")
          description("Schema for actives/inactives ")

          properties do
            account_pubkey(Schema.array(:ActiveInactive), "The account info")
          end
        end,
      PointeesResponse:
        swagger_schema do
          title("Pointees")
          description("Response schema for pointees")

          properties do
            active(Schema.ref(:ActivesInactives), "The active info")
            inactive(Schema.ref(:ActivesInactives), "The inactive info")
          end

          example(%{
            active: %{
              account_pubkey: [
                %{
                  active_from: 279_555,
                  expire_height: 329_558,
                  name: "wwwbeaconoidcom.chain",
                  update: %{block_height: 279_558, micro_index: 51, tx_index: 12_942_695}
                }
              ]
            },
            inactive: %{}
          })
        end,
      OwnedByResponse:
        swagger_schema do
          title("Owned by")
          description("Schema for owned by")

          properties do
            active(Schema.array(:NameByIdResponse), "List of active information")
            top_bid(Schema.array(:NameAuctions), "List for names auctions")
          end

          example(%{
            active: [
              %{
                active: true,
                hash: "nm_6oqHuqaHZcTTMMNRXiDpqek1jHqz1cxTtLUeVTdJH8Vs",
                info: %{
                  active_from: 314_867,
                  auction_timeout: 0,
                  claims: [15_721_403],
                  expire_height: 364_910,
                  ownership: %{
                    current: "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah",
                    original: "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
                  },
                  pointers: %{
                    account_pubkey: "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
                  },
                  revoke: nil,
                  transfers: [],
                  updates: [15_723_647]
                },
                name: "arandomtrashpanda.chain",
                previous: [],
                status: "name"
              }
            ],
            top_bid: []
          })
        end
    }
  end

  swagger_path :name do
    get("/name/{id}")
    description("Get information for given name or encoded hash.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_name_by_id")
    tag("Middleware")

    parameters do
      id(:path, :string, "The name or encoded hash",
        required: true,
        example: "wwwbeaconoidcom.chain"
      )
    end

    response(200, "Returns information for given name", Schema.ref(:NameByIdResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :owned_by do
    get("/names/owned_by/{id}")
    description("Get name information for given acount/owner")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_owned_by")
    tag("Middleware")

    parameters do
      id(:path, :string, "The id",
        required: true,
        example: "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      )
    end

    response(200, "Returns names for a given owner", Schema.ref(:OwnedByResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :names do
    get("/names")
    description("Get all active and inactive names, except those in auction.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_all_names")
    tag("Middleware")
    SwaggerParameters.by_params()
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()

    response(200, "Returns information for active and inactive names", Schema.ref(:NamesResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :active_names do
    get("/names/active")
    description("Get active names.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_names")
    tag("Middleware")
    SwaggerParameters.by_params()
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()

    response(200, "Returns information for active names", Schema.ref(:NamesResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :inactive_names do
    get("/names/active")
    description("Get all inactive names.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_inactive_names")
    tag("Middleware")
    SwaggerParameters.by_params()
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()

    response(200, "Returns information for inactive names", Schema.ref(:NamesResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :auctions do
    get("/names/auctions")
    description("Get all auctions.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_all_auctions")
    tag("Middleware")
    SwaggerParameters.by_params()
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()

    response(200, "Returns information for all auctions", Schema.ref(:NamesAuctionsResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :pointers do
    get("/names/pointers/{id}")
    description("Get pointers for given name.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_pointers_by_id")
    tag("Middleware")

    parameters do
      id(:path, :string, "The name",
        required: true,
        example: "wwwbeaconoidcom.chain"
      )
    end

    response(200, "Returns just pointers for given name", Schema.ref(:PointersResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :pointees do
    get("/names/pointees/{id}")
    description("Get names pointing to a particular pubkey.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_pointees_by_id")
    tag("Middleware")

    parameters do
      id(:path, :string, "The public key",
        required: true,
        example: "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      )
    end

    response(
      200,
      "Returns names pointing to a particular pubkey, partitioned into active and inactive sets",
      Schema.ref(:PointeesResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end
end
