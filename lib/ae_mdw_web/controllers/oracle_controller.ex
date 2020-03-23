defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller

  # Hardcoded DB only for testing purpose
  @oracles_all [
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

  @oracle_requests_responses []

  def oracles_all(conn, _params) do
    json(conn, @oracles_all)
  end

  def oracle_requests_responses(conn, _params) do
    json(conn, @oracle_requests_responses)
  end
end
