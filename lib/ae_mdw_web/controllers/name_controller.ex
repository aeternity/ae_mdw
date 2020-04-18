defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  # Hardcoded DB only for testing purpose
  @names [
    %{
      "name" => "dinchotodorov.chain",
      "name_hash" => "nm_R9qPY3oGPmQHmmnPYYXhztTVXojWZrMS8mC5LSRSFWA2bVj2a",
      "tx_hash" => "th_2TTF2avZ8XYQQR4NmtieR4fQQLkscocDYG5tTcwAhk5nTELfTA",
      "created_at_height" => 223_763,
      "auction_end_height" => 223_763,
      "owner" => "ak_dvNHMgVvdSgDchLsmcUpuFTbMBGfG3E5V9KZnNjLYPyEhcqnL",
      "expires_at" => 273_763,
      "pointers" => :null
    },
    %{
      "name" => "shelpin.chain",
      "name_hash" => "nm_2R3H9NaXpQM5U6zECiMC6uJJrA2r6bVvxMkKpd8L316YeGb9Sz",
      "tx_hash" => "th_2RH7i1DwL5BEbh7dgVPWMpsYukKDGUc7NGqsXbGCvrejodhX1n",
      "created_at_height" => 223_742,
      "auction_end_height" => 238_622,
      "owner" => "ak_2KLGqJGp1BH5QgpNetNBztDHALgwZjF7GQVYpbJ66z6N9d5mxu",
      "expires_at" => 288_622,
      "pointers" => :null
    }
  ]

  @search_name [
    %{
      "name" => "dinchotodorov.chain",
      "name_hash" => "nm_R9qPY3oGPmQHmmnPYYXhztTVXojWZrMS8mC5LSRSFWA2bVj2a",
      "tx_hash" => "th_2TTF2avZ8XYQQR4NmtieR4fQQLkscocDYG5tTcwAhk5nTELfTA",
      "created_at_height" => 223_763,
      "auction_end_height" => 223_763,
      "owner" => "ak_dvNHMgVvdSgDchLsmcUpuFTbMBGfG3E5V9KZnNjLYPyEhcqnL",
      "expires_at" => 273_763,
      "pointers" => :null
    }
  ]

  @active_name_auctions [
    %{
      "name" => "love.chain",
      "expiration" => 223_887,
      "winning_bid" => "168000000000000000000",
      "winning_bidder" => "ak_2pqYSBpEkykFy11KFZXxDJaB8KugXBi2JxraqZXpTaXzreYb95"
    },
    %{
      "name" => "base.chain",
      "expiration" => 224_131,
      "winning_bid" => "134626900000000000000",
      "winning_bidder" => "ak_2pqYSBpEkykFy11KFZXxDJaB8KugXBi2JxraqZXpTaXzreYb95"
    }
  ]

  @active_name_auctions_count %{
    "count" => 85,
    "result" => "OK"
  }

  @name_auctions_bids_by_address [
    %{
      "name_auction_entry" => %{
        "name" => "keno.chain",
        "expiration" => 224_805,
        "winning_bid" => "134626900000000000000",
        "winning_bidder" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS"
      },
      "transaction" => %{
        "block_height" => 195_045,
        "block_hash" => "mh_397S1QJjBDMJ8E5nDbDUSUQGwWcHYjcrQDUx3bLMTZXr3B9Bf",
        "hash" => "th_25ihEDihisD3iwmNnEfJGWSgRuPpPBXPJB84JFRXqJXD7mGmk9",
        "signatures" =>
          "sg_Y97AkuNifvRhKeJSnR6mPw9cGxwLnVWi7SNCEVwuu1uD46pr3QWvW1ikWprpAUqS5Zo5Dc5zTF6n55WgDvEdSZ1WkB5QT",
        "tx_type" => "NameClaimTx",
        "tx" => %{
          "account_id" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
          "fee" => 16_520_000_000_000,
          "name" => "keno.chain",
          "name_fee" => 134_626_900_000_000_000_000,
          "name_salt" => 4_187_908_362_486_519,
          "nonce" => 12,
          "type" => "NameClaimTx",
          "version" => 2
        },
        "fee" => "16520000000000",
        "size" => 206
      }
    }
  ]

  @name_auctions_bids_by_name [
    %{
      "block_height" => 195_045,
      "block_hash" => "mh_397S1QJjBDMJ8E5nDbDUSUQGwWcHYjcrQDUx3bLMTZXr3B9Bf",
      "hash" => "th_25ihEDihisD3iwmNnEfJGWSgRuPpPBXPJB84JFRXqJXD7mGmk9",
      "signatures" =>
        "sg_Y97AkuNifvRhKeJSnR6mPw9cGxwLnVWi7SNCEVwuu1uD46pr3QWvW1ikWprpAUqS5Zo5Dc5zTF6n55WgDvEdSZ1WkB5QT",
      "tx_type" => "NameClaimTx",
      "tx" => %{
        "account_id" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
        "fee" => 16_520_000_000_000,
        "name" => "keno.chain",
        "name_fee" => 134_626_900_000_000_000_000,
        "name_salt" => 4_187_908_362_486_519,
        "nonce" => 12,
        "type" => "NameClaimTx",
        "version" => 2
      },
      "fee" => "16520000000000",
      "size" => 206
    }
  ]

  @name_by_address [
    %{
      "name" => "kenodressel.chain",
      "name_hash" => "nm_2fALUk7nXnZ8CZqzwa1NUTRWdpoNaYzfWQoYbaVoKSyHyoXyXi",
      "tx_hash" => "th_vj8yf5pFZKeMZPd86f33uqtgWu8f2j4HmKBuebsMPhkemb8pe",
      "created_at_height" => 220_765,
      "auction_end_height" => 221_245,
      "owner" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
      "expires_at" => 271_371,
      "pointers" => [
        %{
          "id" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
          "key" => "account_pubkey"
        }
      ]
    }
  ]

  @auction_info %{
    "bids" => [
      %{
        "block_height" => 195_045,
        "block_hash" => "mh_397S1QJjBDMJ8E5nDbDUSUQGwWcHYjcrQDUx3bLMTZXr3B9Bf",
        "hash" => "th_25ihEDihisD3iwmNnEfJGWSgRuPpPBXPJB84JFRXqJXD7mGmk9",
        "signatures" =>
          "sg_Y97AkuNifvRhKeJSnR6mPw9cGxwLnVWi7SNCEVwuu1uD46pr3QWvW1ikWprpAUqS5Zo5Dc5zTF6n55WgDvEdSZ1WkB5QT",
        "tx_type" => "NameClaimTx",
        "tx" => %{
          "account_id" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
          "fee" => 16_520_000_000_000,
          "name" => "keno.chain",
          "name_fee" => 134_626_900_000_000_000_000,
          "name_salt" => 4_187_908_362_486_519,
          "nonce" => 12,
          "type" => "NameClaimTx",
          "version" => 2
        },
        "fee" => "16520000000000",
        "size" => 206
      }
    ],
    "info" => %{
      "name" => "keno.chain",
      "expiration" => 224_805,
      "winning_bid" => "134626900000000000000",
      "winning_bidder" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS"
    }
  }

  @name_for_hash %{
    "name" => %{
      "auction_end_height" => 221_245,
      "created_at_height" => 220_765,
      "expires_at" => 271_371,
      "name" => "kenodressel.chain",
      "name_hash" => "nm_2fALUk7nXnZ8CZqzwa1NUTRWdpoNaYzfWQoYbaVoKSyHyoXyXi",
      "owner" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
      "pointers" => [
        %{
          "id" => "ak_rWHahs7yKku8tFfpPU67ALmmwvD89SAcXYGDM4imzCHSGqhBS",
          "key" => "account_pubkey"
        }
      ],
      "tx_hash" => "th_vj8yf5pFZKeMZPd86f33uqtgWu8f2j4HmKBuebsMPhkemb8pe"
    }
  }

  swagger_path :all_names do
    get("/names")
    description("Get all names")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_all_names")

    parameters do
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")
    end

    response(200, "", %{})
  end

  def all_names(conn, _params) do
    json(conn, @names)
  end

  swagger_path :search_name do
    get("/names/{name}")
    description("Search for a name")
    produces(["application/json"])
    deprecated(false)
    operation_id("search_name")

    parameters do
      name(:path, :string, "String to match and find the name against", required: true)
    end

    response(200, "", %{})
  end

  def search_name(conn, _params) do
    json(conn, @search_name)
  end

  swagger_path :active_names do
    get("/names/active")
    description("Get a list of all the active names")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_names")

    parameters do
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")

      owner(:query, :string, "Address of the owner account to filter the results", required: false)
    end

    response(200, "", %{})
  end

  def active_names(conn, _params) do
    json(conn, @names)
  end

  swagger_path :active_name_auctions do
    get("/names/auctions/active")
    description("Get a list of all the active name auctions")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_name_auctions")

    parameters do
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")

      length(:query, :integer, "Returns the names with provided length",
        required: false,
        format: "int32"
      )

      reverse(
        :query,
        :string,
        "No value needs to be provided. If present the response will be reversed",
        required: false
      )

      sort(:query, :string, "Can be 'name', 'max_bid' or 'expiration'(default)", required: false)
    end

    response(200, "", %{})
  end

  def active_name_auctions(conn, _params) do
    json(conn, @active_name_auctions)
  end

  swagger_path :active_name_auctions_count do
    get("/names/auctions/active/count")
    description("Get a count of all the active name auctions")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_name_auctions_count")

    parameters do
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")

      length(:query, :integer, "Returns the names with provided length",
        required: false,
        format: "int32"
      )

      reverse(
        :query,
        :string,
        "No value needs to be provided. If present the response will be reversed",
        required: false
      )

      sort(:query, :string, "Can be 'name', 'max_bid' or 'expiration'(default)", required: false)
    end

    response(200, "", %{})
  end

  def active_name_auctions_count(conn, _params) do
    json(conn, @active_name_auctions_count)
  end

  swagger_path :name_auctions_bids_by_address do
    get("/names/auctions/bids/account/{account}")
    description("Get bids made by a given account")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_name_auctions_bids_by_address")

    parameters do
      account(:path, :string, "Account address", required: true)
      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
    end

    response(200, "", %{})
  end

  def name_auctions_bids_by_address(conn, _params) do
    json(conn, @name_auctions_bids_by_address)
  end

  swagger_path :name_auctions_bids_by_name do
    get("/names/auctions/bids/{name}")
    description("Get a bids for a given name")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_name_auctions_bids_by_name")

    parameters do
      name(:path, :string, "Name to fetch the bids for", required: true)
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")
    end

    response(200, "", %{})
  end

  def name_auctions_bids_by_name(conn, _params) do
    json(conn, @name_auctions_bids_by_name)
  end

  swagger_path :name_by_address do
    get("/names/reverse/{account}")
    description("Get a list of names mapped to the given address")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_name_by_address")

    parameters do
      account(:path, :string, "Account address", required: true)
      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
    end

    response(200, "", %{})
  end

  def name_by_address(conn, _params) do
    json(conn, @name_by_address)
  end

  swagger_path :auction_info do
    get("/names/auctions/{name}/info")
    description("Get info in a given auction")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_auction_info")

    parameters do
      name(:path, :string, "The name to get info on", required: true)
    end

    response(200, "", %{})
  end

  def auction_info(conn, _params) do
    json(conn, @auction_info)
  end

  swagger_path :name_for_hash do
    get("/names/hash/{hash}")
    description("Given a name hash, return the name and associated info")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_name_for_hash")

    parameters do
      hash(:path, :string, "The hash of the name", required: true)
    end

    response(200, "", %{})
  end

  def name_for_hash(conn, _params) do
    json(conn, @name_for_hash)
  end
end
