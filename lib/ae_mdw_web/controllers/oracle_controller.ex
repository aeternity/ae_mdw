defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

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
    operation_id("all_oracles")

    parameters do
      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
    end

    response(200, "", %{})
  end

  def all_oracles(conn, _params) do
    json(conn, @all_oracles)
  end

  swagger_path :oracle_data do
    get("/oracles/{oracle_id}")
    description("Get a list of query and response for a given oracle")
    produces(["application/json"])
    deprecated(false)
    operation_id("oracle_data")

    parameters do
      oracle_id(:path, :string, "Oracle address/id to get the query and responses", required: true)

      limit(:query, :integer, "", required: false, format: "int32")
      page(:query, :integer, "", required: false, format: "int32")
    end

    response(200, "", %{})
  end

  def oracle_data(conn, _params) do
    json(conn, @oracle_data)
  end
end
