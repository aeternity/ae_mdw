defmodule AeMdwWeb.Aex9Controller do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Aex9
  alias AeMdw.AexnTokens
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Util
  alias AeMdw.Aex9
  alias AeMdwWeb.DataStreamPlug, as: DSPlug
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  import AeMdwWeb.Util, only: [handle_input: 2, paginate: 4, presence?: 2]
  import AeMdwWeb.Helpers.AexnHelper
  import AeMdwWeb.AexnView

  plug(PaginatedPlug)

  @max_range_length 10

  @spec by_contract(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_contract(conn, %{"id" => contract_id}),
    do: handle_input(conn, fn -> by_contract_reply(conn, contract_id) end)

  @spec by_names(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_names(conn, params),
    do: handle_input(conn, fn -> by_names_reply(conn, params) end)

  @spec by_symbols(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def by_symbols(conn, params),
    do: handle_input(conn, fn -> by_symbols_reply(conn, params) end)

  @spec balance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balance(conn, %{"contract_id" => contract_id, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          balance_reply(
            conn,
            ensure_aex9_contract_pk!(contract_id),
            Validate.id!(account_id, [:account_pubkey])
          )
        end
      )

  @spec balance_range(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @spec balance_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @spec balances(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def balances(conn, %{"height" => height, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])

          txi =
            Util.block_txi(Validate.nonneg_int!(height)) ||
              raise ErrInput.BlockIndex, value: height

          account_balances_reply(conn, account_pk, txi)
        end
      )

  def balances(conn, %{"blockhash" => hash, "account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])

          bi =
            Util.block_hash_to_bi(Validate.id!(hash)) ||
              raise ErrInput.Id, value: hash

          account_balances_reply(conn, account_pk, Util.block_txi(bi))
        end
      )

  def balances(conn, %{"account_id" => account_id}),
    do:
      handle_input(
        conn,
        fn ->
          account_pk = Validate.id!(account_id, [:account_pubkey])
          account_balances_reply(conn, account_pk)
        end
      )

  def balances(conn, %{"contract_id" => contract_id}),
    do: handle_input(conn, fn -> balances_reply(conn, ensure_aex9_contract_pk!(contract_id)) end)

  @spec balances_range(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @spec balances_for_hash(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @spec transfers_from_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_v1(conn, %{"sender" => sender_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:from, Validate.id!(sender_id)}, :aex9_transfer) end
      )

  @spec transfers_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_to_v1(conn, %{"recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn -> transfers_reply(conn, {:to, Validate.id!(recipient_id)}, :rev_aex9_transfer) end
      )

  @spec transfers_from_to_v1(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_to_v1(conn, %{"sender" => sender_id, "recipient" => recipient_id}),
    do:
      handle_input(
        conn,
        fn ->
          query = {:from_to, Validate.id!(sender_id), Validate.id!(recipient_id)}
          transfers_reply(conn, query, :aex9_pair_transfer)
        end
      )

  @spec transfers_from(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from(%Conn{assigns: assigns} = conn, %{"sender" => sender_id}) do
    %{pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, transfers_keys, next_cursor} =
      sender_id
      |> Validate.id!()
      |> Aex9.fetch_sender_transfers(pagination, cursor)

    data = Enum.map(transfers_keys, &sender_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  @spec transfers_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_to(%Conn{assigns: assigns} = conn, %{"recipient" => recipient_id}) do
    %{pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, transfers_keys, next_cursor} =
      recipient_id
      |> Validate.id!()
      |> Aex9.fetch_recipient_transfers(pagination, cursor)

    data = Enum.map(transfers_keys, &recipient_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  @spec transfers_from_to(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfers_from_to(%Conn{assigns: assigns} = conn, %{
        "sender" => sender_id,
        "recipient" => recipient_id
      }) do
    %{pagination: pagination, cursor: cursor} = assigns

    sender_pk = Validate.id!(sender_id)
    recipient_pk = Validate.id!(recipient_id)

    {prev_cursor, transfers_keys, next_cursor} =
      Aex9.fetch_pair_transfers(sender_pk, recipient_pk, pagination, cursor)

    data = Enum.map(transfers_keys, &pair_transfer_to_map/1)

    paginate(conn, prev_cursor, data, next_cursor)
  end

  #
  # Private functions
  #
  defp transfers_reply(conn, query, key_tag) do
    transfers =
      query
      |> Contract.aex9_search_transfers()
      |> Stream.map(&transfer_to_map(&1, key_tag))
      |> Enum.sort_by(fn %{call_txi: call_txi} -> call_txi end)

    json(conn, transfers)
  end

  defp by_contract_reply(conn, contract_id) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aex9} <- AexnTokens.fetch_token({:aex9, contract_pk}) do
      json(conn, %{data: render_token(m_aex9)})
    end
  end

  defp by_names_reply(conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_tokens(pagination, :aex9, params, :name, nil) do
      json(conn, render_tokens(aex9_tokens))
    end
  end

  defp by_symbols_reply(conn, params) do
    pagination = {:forward, false, 32_000, false}

    with {:ok, _prev_cursor, aex9_tokens, _next_cursor} <-
           AexnTokens.fetch_tokens(pagination, :aex9, params, :symbol, nil) do
      json(conn, render_tokens(aex9_tokens))
    end
  end

  defp balance_reply(conn, contract_pk, account_pk) do
    {amount, {type, height, hash}} =
      if top?(conn) do
        DBN.aex9_balance(contract_pk, account_pk, top?(conn))
      else
        case Aex9.fetch_amount_and_keyblock(contract_pk, account_pk) do
          {:ok, {amount, kb_height_hash}} ->
            {amount, kb_height_hash}

          {:error, unavailable_error} ->
            raise unavailable_error
        end
      end

    json(conn, balance_to_map({amount, {type, height, hash}}, contract_pk, account_pk))
  end

  defp balance_range_reply(conn, contract_pk, account_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        account_id: enc_id(account_pk),
        range:
          map_balances_range(
            range,
            fn type_height_hash ->
              {amount, _} = DBN.aex9_balance(contract_pk, account_pk, type_height_hash)
              {:amount, amount}
            end
          )
      }
    )
  end

  defp balance_for_hash_reply(conn, contract_pk, account_pk, {type, block_hash, height}) do
    {amount, _} = DBN.aex9_balance(contract_pk, account_pk, {type, height, block_hash})
    json(conn, balance_to_map({amount, {type, height, block_hash}}, contract_pk, account_pk))
  end

  defp account_balances_reply(conn, account_pk) do
    balances =
      account_pk
      |> Contract.aex9_search_contracts()
      |> Enum.map(fn contract_pk ->
        case Aex9.fetch_amount(contract_pk, account_pk) do
          {:ok, {amount, call_txi}} ->
            {amount, call_txi, contract_pk}

          {:error, unavailable_error} ->
            raise unavailable_error
        end
      end)
      |> Enum.map(&balance_to_map/1)

    json(conn, balances)
  end

  defp account_balances_reply(conn, account_pk, last_txi) do
    contracts =
      account_pk
      |> Contract.aex9_search_contract(last_txi)
      |> Map.to_list()
      |> Enum.sort_by(fn {_ct_pk, txi_list} -> _call_txi = List.last(txi_list) end)

    height_hash = DBN.top_height_hash(top?(conn))

    balances =
      contracts
      |> Enum.map(fn {contract_pk, txi_list} ->
        {amount, _} = DBN.aex9_balance(contract_pk, account_pk, height_hash)
        call_txi = List.last(txi_list)
        {amount, call_txi, contract_pk}
      end)
      |> Enum.map(&balance_to_map/1)

    json(conn, balances)
  end

  defp balances_reply(conn, contract_pk) do
    amounts = Aex9.fetch_balances(contract_pk, top?(conn))
    hash_tuple = DBN.top_height_hash(top?(conn))
    json(conn, balances_to_map({amounts, hash_tuple}, contract_pk))
  end

  defp balances_range_reply(conn, contract_pk, range) do
    json(
      conn,
      %{
        contract_id: enc_ct(contract_pk),
        range:
          map_balances_range(
            range,
            fn type_height_hash ->
              {amounts, _} = DBN.aex9_balances!(contract_pk, type_height_hash)
              {:amounts, normalize_balances(amounts)}
            end
          )
      }
    )
  end

  defp balances_for_hash_reply(conn, contract_pk, {block_type, block_hash, height}) do
    {amounts, _} = DBN.aex9_balances!(contract_pk, {block_type, height, block_hash})
    json(conn, balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk))
  end

  defp parse_range!(range) do
    case DSPlug.parse_range(range) do
      {:ok, %Range{first: f, last: l}} ->
        {:ok, top_kb} = :aec_chain.top_key_block()
        first = max(0, f)
        last = min(l, :aec_blocks.height(top_kb))

        if last - first + 1 > @max_range_length do
          raise ErrInput.RangeTooBig, value: "max range length is #{@max_range_length}"
        end

        first..last

      {:error, _detail} ->
        raise ErrInput.NotAex9, value: range
    end
  end

  defp ensure_aex9_contract_pk!(ct_ident) do
    pk = Validate.id!(ct_ident, [:contract_pubkey])
    AeMdw.Contract.is_aex9?(pk) || raise ErrInput.NotAex9, value: ct_ident
    pk
  end

  defp ensure_block_hash_and_height!(block_ident) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_ident) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} ->
            {:aec_blocks.type(block), block_hash, :aec_blocks.height(block)}

          :error ->
            raise ErrInput.NotFound, value: block_ident
        end

      _any_error ->
        raise ErrInput.Query, value: block_ident
    end
  end

  defp top?(conn), do: presence?(conn, "top")

  defp map_balances_range(range, get_balance_func) do
    range
    |> Stream.map(&height_hash/1)
    |> Stream.map(fn {height, hash} ->
      {k, v} = get_balance_func.({:key, height, hash})
      Map.put(%{height: height, block_hash: enc_block(:key, hash)}, k, v)
    end)
    |> Enum.to_list()
  end

  defp height_hash(height) do
    with {:ok, block} <- :aec_chain.get_key_block_by_height(height),
         {:ok, hash} <- :aec_headers.hash_header(:aec_blocks.to_header(block)) do
      {height, hash}
    else
      _error -> {height, <<>>}
    end
  end

  #
  # Swagger
  #
  @spec swagger_definitions() :: map()
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
        end,
      Aex9TransferResponse:
        swagger_schema do
          title("Aex9Response")
          description("Response Schema for AEX9 transfer responses")

          properties do
            amount(:integer, "Transfer amount of AEX9 token", required: true)
            call_txi(:integer, "AEX9 token transfer index", required: true)
            log_idx(:integer, "Log index", required: true)
            recipient(:string, "Recipient of AEX9 transfer", required: true)
            sender(:string, "Sender of AEX9 transfer", required: true)
            block_height(:integer, "The block height", required: true)
            micro_time(:integer, "The unix timestamp", required: true)
            contract_id(:string, "Contract identifier", required: true)
          end

          example(%{
            amount: 2,
            call_txi: 9_564_978,
            log_idx: 0,
            recipient: "ak_29GUBTrWTMb3tRUUgbVX1Bgwi2hyVhB8Q1befNsjLnP46Ub1V8",
            sender: "ak_2CMNYSgoEjb1GSVJfWXjZ9NFWwnJ9jySBd6YY7uyr5DxvwctZU",
            block_height: 234_208,
            micro_time: 1_585_667_337_719,
            contract_id: "ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5"
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
    description("Get all current AEX9 token balances for given contract")
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
    description("Get all AEX9 token balances at block for given contract")
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

  swagger_path :aex9_balances_for_account_by_height do
    get("aex9/balances/gen/{height}/account/{account_id}")
    description("Get AEX9 token balances of all contracts at height for given account")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances_for_account_by_height")
    tag("Middleware")

    parameters do
      height(:path, :integer, "Block height",
        reqired: true,
        example: "384669"
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

  swagger_path :aex9_balances_for_account_by_blockhash do
    get("aex9/balances/hash/{blockhash}/account/{account_id}")
    description("Get AEX9 token balances of all contracts at blockhash for given account")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances_for_account_by_blockhash")
    tag("Middleware")

    parameters do
      blockhash(:path, :string, "Block hash",
        reqired: true,
        example: "kh_2hXEoFTmMphpvCmvdvQTZtGu9a3RndL5fSvVqzKBs2DSNJjQ2V"
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

  swagger_path :aex9_balances_by_account do
    get("aex9/balances/account/{account_id}")
    description("Get current AEX9 token balances of all contracts for given account")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_balances_by_account")
    tag("Middleware")

    parameters do
      account_id(:path, :string, "Account id",
        reqired: true,
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

  swagger_path :aex9_transfers_by_sender do
    get("/aex9/transfers/from/{sender}")
    description("Get all transfers of AEX9 tokens from sender")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_transfers_by_sender")
    tag("Middleware")

    parameters do
      account_id(:path, :string, "Account id",
        reqired: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns transfer information by given criteria",
      Schema.ref(:Aex9TransferResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_transfers_by_recipient do
    get("/aex9/transfers/to/{recipient}")
    description("Get all transfers of AEX9 tokens to recipient")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_aex9_transfers_by_recipient")
    tag("Middleware")

    parameters do
      recipient(:path, :string, "Recipient id",
        reqired: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns transfer information by given criteria",
      Schema.ref(:Aex9TransferResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_transfers_by_sender_and_recipient do
    get("/aex9/transfers/from-to/{sender}/{recipient}")
    produces(["application/json"])
    description("Get all transfers of AEX9 tokens between sender and recipient")
    deprecated(false)
    operation_id("get_aex9_transfers_by_sender_and_recipient")
    tag("Middleware")

    parameters do
      sender(:path, :string, "Sender id",
        reqired: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )

      recipient(:path, :string, "Recipient id",
        reqired: true,
        example: "ak_Yc8Lr64xGiBJfm2Jo8RQpR1gwTY8KMqqXk8oWiVC9esG8ce48"
      )
    end

    response(
      200,
      "Returns balance information by given criteria",
      Schema.ref(:Aex9TransferResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :aex9_balances_by_range do
    get("aex9/balances/gen/{range}/{contract_id}")

    description("Get all AEX9 token balances in range for given contract")

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
