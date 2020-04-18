defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Validate
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdw.{Sigil, Util}

  # Hardcoded DB only for testing purpose
  @all_oracles [
    %{
      "block_height" => 221_376,
      "expires_at" => 221_876,
      "oracle_id" => "ok_Gb6cD91w29v8csjAxyyBmfAQmdNo1aUedWkhn9HxqiXeVuGcj",
      "transaction_hash" => "th_UCk7W7UgLx3DZiakpQnRdAsBWnMEELykUyDFiSzVdMwfsSQPV",
      "tx" => %{
        "abi_version" => 0,
        "account_id" => "ak_Gb6cD91w29v8csjAxyyBmfAQmdNo1aUedWkhn9HxqiXeVuGcj",
        "fee" => 16_552_000_000_000,
        "nonce" => 1,
        "oracle_ttl" => %{
          "type" => "delta",
          "value" => 500
        },
        "query_fee" => 20_000_000_000_000,
        "query_format" => "string",
        "response_format" => "string",
        "type" => "OracleRegisterTx",
        "version" => 1
      }
    },
    %{
      "block_height" => 220_325,
      "expires_at" => 220_825,
      "oracle_id" => "ok_2ChQprgcW1od3URuRWnRtm1sBLGgoGZCDBwkyXD1U7UYtKUYys",
      "transaction_hash" => "th_2ACk4bkDJMXB7y9MC7KasAyquSsmw5yWKP75DoFkC96vAjsjrd",
      "tx" => %{
        "abi_version" => 0,
        "account_id" => "ak_2ChQprgcW1od3URuRWnRtm1sBLGgoGZCDBwkyXD1U7UYtKUYys",
        "fee" => 16_552_000_000_000,
        "nonce" => 19,
        "oracle_ttl" => %{
          "type" => "delta",
          "value" => 500
        },
        "query_fee" => 20_000_000_000_000,
        "query_format" => "string",
        "response_format" => "string",
        "type" => "OracleRegisterTx",
        "version" => 1
      }
    },
    %{
      "block_height" => 220_325,
      "expires_at" => 220_825,
      "oracle_id" => "ok_NcsdzkY5TWD3DY2f9o87MruJ6FSUYRiuRPpv5Rd2sqsvG1V2m",
      "transaction_hash" => "th_qxDUtCg46yGRB7ceTp4aKx7xjuth5rZPSVsvGXTM4QzRcVhAN",
      "tx" => %{
        "abi_version" => 0,
        "account_id" => "ak_NcsdzkY5TWD3DY2f9o87MruJ6FSUYRiuRPpv5Rd2sqsvG1V2m",
        "fee" => 16_552_000_000_000,
        "nonce" => 19,
        "oracle_ttl" => %{
          "type" => "delta",
          "value" => 500
        },
        "query_fee" => 20_000_000_000_000,
        "query_format" => "string",
        "response_format" => "string",
        "type" => "OracleRegisterTx",
        "version" => 1
      }
    }
  ]

  @oracle_data []

  swagger_path :all_oracles do
    get("/oracles/list")
    description("Get a list of oracles")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_all_oracles")

    parameters do
      limit(:query, :integer, "", required: true, format: "int32")
      page(:query, :integer, "", required: true, format: "int32")
    end

    response(200, "", %{})
  end

  def all_oracles(conn, _req),
    do: json(conn, Cont.response(conn, &db_stream/1))

  swagger_path :oracle_data do
    get("/oracles/{oracle_id}")
    description("Get a list of query and response for a given oracle")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_oracle_data")

    parameters do
      oracle_id(:path, :string, "Oracle address/id to get the query and responses", required: true)
    end

    response(200, "", %{})
  end

  def oracle_data(conn, _req) do
    data = Cont.response(conn, &db_stream/1)

    data |> hd |> prx("////////// ORACLE RESP")

    json(conn, data)
  end

  def db_stream(req) do
    case req do
      %{"oracle_id" => oracle_id} ->
        :backward
        |> DBS.map(~t[object], {:json, &to_response/1}, {oracle_id, :oracle_response_tx})

      %{} ->
        :backward
        |> DBS.map(~t[type], {:json, &to_oracle/1}, :oracle_register_tx)
    end
  end

  def to_response(%{} = response_tx) do
    tx = response_tx["tx"]
    oracle_id = tx["oracle_id"]
    query_id = tx["query_id"]

    %{
      "query_id" => query_id,
      "request" => %{
        "oracle_id" => oracle_id,
        "hash" => "TODO: request_hash",
        "query" => "TODO: query"
      },
      "response" => %{"hash" => response_tx["hash"], "response" => tx["response"]}
    }
  end

  def to_oracle(%{} = register_tx) do
    %{
      "block_height" => height,
      "hash" => tx_hash,
      "tx" => %{"account_id" => account_id, "oracle_ttl" => oracle_ttl}
    } = register_tx

    expiration_height =
      case oracle_ttl do
        %{"type" => :delta, "value" => ttl_val} -> height + ttl_val
        %{"type" => :block, "value" => ttl_val} -> ttl_val
      end

    oracle_id = :aeser_id.create(:oracle, Validate.id!(account_id))

    register_tx
    |> Map.delete("hash")
    |> Map.put("transaction_hash", tx_hash)
    |> Map.put("expires_at", expiration_height)
    |> Map.put("oracle_id", :aeser_api_encoder.encode(:id_hash, oracle_id))
  end
end
