defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller

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

  @search_names [
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

  @bids_for_account [
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

  @bids_for_name [
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

  @reverse_names [
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

  @info_for_auction %{
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

  def all_names(conn, _params) do
    json(conn, @names)
  end

  def search_names(conn, _params) do
    json(conn, @search_names)
  end

  def active_names(conn, _params) do
    json(conn, @names)
  end

  def active_name_auctions(conn, _params) do
    json(conn, @active_name_auctions)
  end

  def active_name_auctions_count(conn, _params) do
    json(conn, @active_name_auctions_count)
  end

  def bids_for_account(conn, _params) do
    json(conn, @bids_for_account)
  end

  def bids_for_name(conn, _params) do
    json(conn, @bids_for_name)
  end

  def reverse_names(conn, _params) do
    json(conn, @reverse_names)
  end

  def info_for_auction(conn, _params) do
    json(conn, @info_for_auction)
  end

  def name_for_hash(conn, _params) do
    json(conn, @name_for_hash)
  end
end
