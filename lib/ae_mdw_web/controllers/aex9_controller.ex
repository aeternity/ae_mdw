defmodule AeMdwWeb.Aex9Controller do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Db.{Format, Model, Contract}
  alias AeMdwWeb.SwaggerParameters
  alias AeMdwWeb.DataStreamPlug, as: DSPlug

  import AeMdwWeb.Util

  ##########

  def by_names(conn, params),
    do: handle_input(conn, fn -> by_names_reply(conn, search_mode!(params)) end)

  def by_symbols(conn, params),
    do: handle_input(conn, fn -> by_symbols_reply(conn, search_mode!(params)) end)

  def balance(conn, %{"contract_id" => contract_id, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          balance_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            Validate.id!(account_id, [:account_pubkey]))
        end
      )

  def balance_range(conn, %{
        "range" => range,
        "contract_id" => contract_id,
        "account_id" => account_id
      }),
      do:
        handle_input(
          conn,
          fn ->
            balance_range_reply(
              conn,
              ensure_aex9_contract_pk!(contract_id),
              Validate.id!(account_id, [:account_pubkey]),
              parse_range!(range)
            )
          end
        )

  def balance_for_hash(conn, %{
        "blockhash" => block_hash_enc,
        "contract_id" => contract_id,
        "account_id" => account_id
      }),
      do:
        handle_input(
          conn,
          fn ->
            balance_for_hash_reply(
              conn,
              ensure_aex9_contract_pk!(contract_id),
              Validate.id!(account_id, [:account_pubkey]),
              ensure_block_hash_and_height!(block_hash_enc)
            )
          end
        )

  def balances(conn, %{"height" => height, "account_id" => account_id}),
    do: handle_input(conn,
          fn ->
            account_pk = Validate.id!(account_id, [:account_pubkey])
            txi = AeMdw.Db.Util.block_txi(Validate.nonneg_int!(height)) ||
              raise ErrInput.BlockIndex, value: height
            account_balances_reply(conn, account_pk, txi)
          end)

  def balances(conn, %{"blockhash" => hash, "account_id" => account_id}),
    do: handle_input(conn,
          fn ->
            account_pk = Validate.id!(account_id, [:account_pubkey])
            bi = AeMdw.Db.Util.block_hash_to_bi(Validate.id!(hash)) ||
              raise ErrInput.Id, value: hash
            account_balances_reply(conn, account_pk, AeMdw.Db.Util.block_txi(bi))
          end)

  def balances(conn, %{"account_id" => account_id}),
    do: handle_input(conn,
          fn ->
            account_pk = Validate.id!(account_id, [:account_pubkey])
            account_balances_reply(conn, account_pk, AeMdw.Db.Util.last_txi())
          end)

  def balances(conn, %{"contract_id" => contract_id}),
    do: handle_input(conn, fn -> balances_reply(conn, ensure_aex9_contract_pk!(contract_id)) end)

  def balances_range(conn, %{"range" => range, "contract_id" => contract_id}),
    do:
      handle_input(
        conn,
        fn ->
          balances_range_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            parse_range!(range)
          )
        end
      )

  def balances_for_hash(conn, %{"blockhash" => block_hash_enc, "contract_id" => contract_id}),
    do:
      handle_input(
        conn,
        fn ->
          balances_for_hash_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            ensure_block_hash_and_height!(block_hash_enc)
          )
        end
      )

  def transfers_from(conn, %{"sender" => sender_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:from, Validate.id!(sender_id)}, :aex9_transfer) end
      )

  def transfers_to(conn, %{"recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:to, Validate.id!(recipient_id)}, :rev_aex9_transfer) end
      )

  def transfers_from_to(conn, %{"sender" => sender_id, "recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn ->
          query = {:from_to, Validate.id!(sender_id), Validate.id!(recipient_id)}
          transfers_reply(conn, query, :aex9_transfer)
        end
      )

  ##########

  def by_names_reply(conn, search_mode) do
    entries =
      Contract.aex9_search_name(search_mode)
      |> Enum.map(&Format.to_map(&1, Model.Aex9Contract))

    json(conn, entries)
  end

  def by_symbols_reply(conn, search_mode) do
    entries =
      Contract.aex9_search_symbol(search_mode)
      |> Enum.map(&Format.to_map(&1, Model.Aex9ContractSymbol))

    json(conn, entries)
  end

  def balance_reply(conn, contract_pk, account_pk) do
    {amount, {type, height, hash}} = DBN.aex9_balance(contract_pk, account_pk, top?(conn))
    json(conn, balance_to_map({amount, {type, height, hash}}, contract_pk, account_pk))
  end

  def balance_range_reply(conn, contract_pk, account_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        account_id: enc_id(account_pk),
        range:
          map_balances_range(
            range,
            fn height_hash ->
              {amount, _} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
              {:amount, amount}
            end
          )
      }
    )
  end

  def balance_for_hash_reply(conn, contract_pk, account_pk, {type, block_hash, height}) do
    {amount, _} = DBN.aex9_balance(contract_pk, account_pk, {height, block_hash})
    json(conn, balance_to_map({amount, {type, height, block_hash}}, contract_pk, account_pk))
  end


  def account_balances_reply(conn, account_pk, last_txi) do
    contracts =
      AeMdw.Db.Contract.aex9_search_contract(account_pk, last_txi)
      |> Map.to_list
      |> Enum.sort_by(&elem(&1, 1), &<=/2)

    height_hash = DBN.top_height_hash(top?(conn))

    balances =
      contracts
      |> Enum.map(fn {contract_pk, txi} ->
           {amount, _} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
           {amount, txi, contract_pk}
         end)
      |> Enum.map(&balance_to_map/1)

    json(conn, balances)
  end


  def balances_reply(conn, contract_pk) do
    {amounts, {type, height, hash}} = DBN.aex9_balances(contract_pk, top?(conn))
    json(conn, balances_to_map({amounts, {type, height, hash}}, contract_pk))
  end

  def balances_range_reply(conn, contract_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        range:
          map_balances_range(
            range,
            fn height_hash ->
              {amounts, _} = DBN.aex9_balances(contract_pk, height_hash)
              {:amounts, normalize_balances(amounts)}
            end
          )
      }
    )
  end

  def balances_for_hash_reply(conn, contract_pk, {block_type, block_hash, height}) do
    {amounts, _} = DBN.aex9_balances(contract_pk, {height, block_hash})
    json(conn, balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk))
  end

  def transfers_reply(conn, query, key_tag) do
    transfers = Contract.aex9_search_transfers(query)
    json(conn, Enum.map(transfers, &transfer_to_map(&1, key_tag)))
  end

  ##########

  def search_mode!(%{"prefix" => _, "exact" => _}),
    do: raise(ErrInput.Query, value: "can't use both `prefix` and `exact` parameters")

  def search_mode!(%{"exact" => exact}),
    do: {:exact, URI.decode(exact)}

  def search_mode!(%{} = params),
    do: {:prefix, URI.decode(Map.get(params, "prefix", ""))}

  def parse_range!(range) do
    case DSPlug.parse_range(range) do
      {:ok, %Range{first: f, last: l}} ->
        {:ok, top_kb} = :aec_chain.top_key_block()
        max(0, f)..min(l, :aec_blocks.height(top_kb))

      {:error, _detail} ->
        raise ErrInput.NotAex9, value: range
    end
  end

  def ensure_aex9_contract_pk!(ct_ident) do
    pk = Validate.id!(ct_ident, [:contract_pubkey])
    AeMdw.Contract.is_aex9?(pk) || raise ErrInput.NotAex9, value: ct_ident
    pk
  end

  def ensure_block_hash_and_height!(block_ident) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_ident) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} ->
            {:aec_blocks.type(block), block_hash, :aec_blocks.height(block)}

          :error ->
            raise ErrInput.NotFound, value: block_ident
        end

      _ ->
        raise ErrInput.Query, value: block_ident
    end
  end

  ##########

  def top?(conn), do: presence?(conn, "top")

  def normalize_balances(bals) do
    for {{:address, pk}, amt} <- bals, reduce: %{} do
      acc ->
        Map.put(acc, :aeser_api_encoder.encode(:account_pubkey, pk), amt)
    end
  end

  def balance_to_map({amount, txi, contract_pk}) do
    tx_idx = AeMdw.Db.Util.read_tx!(txi)
    info = Format.to_raw_map(tx_idx)
    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(:micro, info.block_hash),
      tx_hash: enc(:tx_hash, info.hash),
      tx_index: txi,
      tx_type: info.tx.type,
      height: info.block_height,
      amount: amount
    }
  end

  def balance_to_map({amount, {block_type, height, block_hash}}, contract_pk, account_pk) do
    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(block_type, block_hash),
      height: height,
      account_id: enc_id(account_pk),
      amount: amount
    }
  end

  def balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk) do
    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(block_type, block_hash),
      height: height,
      amounts: normalize_balances(amounts)
    }
  end

  def map_balances_range(range, f) do
    Stream.map(
      height_hash_range(range),
      fn {height, hash} ->
        {k, v} = f.({height, hash})
        Map.put(%{height: height, block_hash: enc_block(:key, hash)}, k, v)
      end
    )
    |> Enum.to_list()
  end

  def height_hash_range(range) do
    Stream.map(
      range,
      fn h ->
        {:ok, block} = :aec_chain.get_key_block_by_height(h)
        {:ok, hash} = :aec_headers.hash_header(:aec_blocks.to_header(block))
        {h, hash}
      end
    )
  end

  def transfer_to_map({recipient_pk, sender_pk, amount, call_txi, log_idx}, :rev_aex9_transfer),
    do: transfer_to_map({sender_pk, recipient_pk, amount, call_txi, log_idx}, :aex9_transfer)

  def transfer_to_map({sender_pk, recipient_pk, amount, call_txi, log_idx}, :aex9_transfer) do
    %{
      sender: enc_id(sender_pk),
      recipient: enc_id(recipient_pk),
      amount: amount,
      call_txi: call_txi,
      log_idx: log_idx
    }
  end

  def enc_block(:key, hash), do: :aeser_api_encoder.encode(:key_block_hash, hash)
  def enc_block(:micro, hash), do: :aeser_api_encoder.encode(:micro_block_hash, hash)

  def enc_ct(pk), do: :aeser_api_encoder.encode(:contract_pubkey, pk)
  def enc_id(pk), do: :aeser_api_encoder.encode(:account_pubkey, pk)

  def enc(type, pk), do: :aeser_api_encoder.encode(type, pk)

  # TODO: swagger
  def swagger_definitions do
    %{
      Aex9Response:
        swagger_schema do
          title("Aex9Response")
          description("Response Schema for AEX9 contract")

          properties do
            name(:string, "The name of AEX9 token", required: true)
            symbol(:string, "The symbol of AEX9 token", required: true)
            decimals(:integer, "The number of decimals for AEX9 token", required: true)
            txi(:integer, "The transaction index of contract create transction", required: true)
          end

          example(%{
            decimals: 18,
            name: "testnetAE",
            symbol: "TTAE",
            txi: 11_145_713
          })
        end,
      Aex9BalanceResponse:
        swagger_schema do
          title("Aex9Response")
          description("Response Schema for AEX9 balance responses")

          properties do
            account_id(:string, "The name of AEX9 token", required: true)
            amount(:integer, "The amount of AEX9 token", required: false)
            amounts(:array, "The amounts of AEX9 token", required: false)

            block_hash(:integer, "The block hash, indicating a state of a balance for that block",
              required: true
            )

            contract_id(:integer, "The contract id of given token", required: true)

            height(
              :integer,
              "The block height, indicating a state of a balance for that block height"
            )

            range(:array, "The range of balances", required: false)
          end

          example(%{
            account_id: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48",
            amount: 49_999_999_999_906_850_000_000_000,
            block_hash: "kh_2QevaXY7ULF5kTLsddwMzzZmBYWPgfaQbg2Y8maZDLKJaPhwDJ",
            contract_id: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA",
            height: 351_666
          })
        end
    }
  end

  swagger_path :aex9_by_name do
    get("/aex9/by_name")
    description("Get AEX9 tokens, sorted by name")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_by_name")
    tag("Middleware")

    parameters do
      all(
        :path,
        :boolean,
        "Used for listing all contract creations for a token, not just the last one",
        required: false,
        example: "true"
      )

      prefix(
        :path,
        :boolean,
        "Used for  for listing tokens with the name or symbol, which are matching by prefix",
        required: false,
        example: "ae"
      )

      exact(
        :path,
        :boolean,
        "Used  for listing tokens with the name or symbol, which are matching by exact argument",
        required: false,
        example: "TNT"
      )
    end

    response(
      200,
      "Returns name information by given criteria",
      Schema.ref(:Aex9Response)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_by_symbol do
    get("aex9/by_symbol")
    description("Get AEX9 tokens, sorted by token symbol")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_by_symbol")
    tag("Middleware")

    parameters do
      all(
        :path,
        :boolean,
        "Used for listing all contract creations for a token, not just the last one",
        required: false,
        example: "true"
      )

      prefix(
        :path,
        :boolean,
        "Used for  for listing tokens with the name or symbol, which are matching by prefix",
        required: false,
        example: "ae"
      )

      exact(
        :path,
        :boolean,
        "Used  for listing tokens with the name or symbol, which are matching by exact argument",
        required: false,
        example: "TNT"
      )
    end

    response(
      200,
      "Returns name information by given criteria",
      Schema.ref(:Aex9Response)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balance do
    get("aex9/balance/{contract_id}/{account_id}")
    description("Get AEX9 token balance by given AEX9 contract id and account id")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balance")
    tag("Middleware")

    parameters do
      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )

      account_id(
        :path,
        :string,
        "Account id",
        required: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balance_by_block do
    get("aex9/balance/hash/{blockhash}/{contract_id}/{account_id}")
    description("Get AEX9 token balance by given AEX9 contract id, account id and block hash")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balance_by_block")
    tag("Middleware")

    parameters do
      blockhash(:path, :string, "Given blockhash",
        reqired: true,
        example: "mh_2NkfQ9p29EQtqL6YQAuLpneTRPxEKspNYLKXeexZ664ZJo7fcw"
      )

      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )

      account_id(
        :path,
        :string,
        "Account id",
        required: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balance_by_range do
    get("aex9/balance/gen/{range}/{contract_id}/{account_id}")

    description(
      "Get AEX9 token balance by given AEX9 contract id, account id and block gen range"
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balance_by_range")
    tag("Middleware")

    parameters do
      range(:path, :string, "Given microblocks range",
        reqired: true,
        example: "350620-350623"
      )

      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )

      account_id(
        :path,
        :string,
        "Account id",
        required: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balances do
    get("aex9/balances/{contract_id}")
    description("Get all AEX9 token balances by given AEX9 contract id")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances")
    tag("Middleware")

    parameters do
      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balances_by_block do
    get("aex9/balances/hash/{blockhash}/{contract_id}")
    description("Getall AEX9 token balances by given AEX9 contract id and block hash")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances_by_block")
    tag("Middleware")

    parameters do
      blockhash(:path, :string, "Given blockhash",
        reqired: true,
        example: "kh_2hXEoFTmMphpvCmvdvQTZtGu9a3RndL5fSvVqzKBs2DSNJjQ2V"
      )

      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balances_by_range do
    get("aex9/balance/gen/{range}/{contract_id}")

    description(
      "Get all AEX9 token balances by given AEX9 contract id and block generations range"
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances_by_range")
    tag("Middleware")

    parameters do
      range(:path, :string, "Given microblocks range",
        reqired: true,
        example: "350620-350623"
      )

      contract_id(
        :path,
        :string,
        "AEX9 token contract id",
        required: true,
        example: "ct_RDRJC5EySx4TcLtGRWYrXfNgyWzEDzssThJYPd9kdLeS5ECaA"
      )

      account_id(
        :path,
        :string,
        "Account id",
        required: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9BalanceResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end
end
