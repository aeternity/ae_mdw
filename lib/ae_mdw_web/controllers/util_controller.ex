defmodule AeMdwWeb.UtilController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  # Hardcoded DB only for testing purpose
  @mdw_status %{
    "OK" => true,
    "errors_last_500_blocks" => 3,
    "queue_length" => 0,
    "seconds_since_last_block" => 52,
    "version" => "0.13.0"
  }

  @current_tx_count %{
    "count" => 8_783_720
  }

  @height_by_time %{
    "height" => 219_764
  }

  @reward_at_height %{
    "beneficiary" => "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
    "coinbase" => "8085815189194932224",
    "fees" => "154584000000000",
    "height" => 224_190,
    "total" => "8085969773194932224"
  }

  @chain_size %{
    "size" => 3_264_432_510
  }
  @size_at_height %{
    "size" => 3_260_992_358
  }

  @compilers %{
    "compilers" => [
      "4.0.0"
    ]
  }

  @height %{"height" => 226_189}

  swagger_path :compilers do
    get("/compilers")
    description("Get list of compilers available to the middleware")
    produces(["application/json"])
    deprecated(false)
    operation_id("compilers")
    response(200, "", %{})
  end

  def compilers(conn, _params) do
    json(conn, @compilers)
  end

  swagger_path :mdw_status do
    get("/status")
    description("Get middleware status")
    produces(["application/json"])
    deprecated(false)
    operation_id("mdw_status")
    response(200, "", %{})
  end

  def mdw_status(conn, _params) do
    json(conn, @mdw_status)
  end

  swagger_path :current_tx_count do
    get("/count/current")
    description("Get count of transactions at the current height")
    produces(["application/json"])
    deprecated(false)
    operation_id("current_tx_count")
    response(200, "", %{})
  end

  def current_tx_count(conn, _params) do
    json(conn, @current_tx_count)
  end

  swagger_path :size_at_height do
    get("/size/height/{height}")
    description("Get size of blockchain at a given height")
    produces(["application/json"])
    deprecated(false)
    operation_id("size_at_height")

    parameters do
      height(:path, :integer, "Blockchain height", required: true)
    end

    response(200, "", %{})
  end

  def size_at_height(conn, _params) do
    json(conn, @size_at_height)
  end

  swagger_path :chain_size do
    get("/size/current")
    description("Get the current of size of blockchain")
    produces(["application/json"])
    deprecated(false)
    operation_id("chain_size")
    response(200, "", %{})
  end

  def chain_size(conn, _params) do
    json(conn, @chain_size)
  end

  swagger_path :reward_at_height do
    get("/reward/height/{height}")
    description("Get the block reward for a given block height")
    produces(["application/json"])
    deprecated(false)
    operation_id("reward_at_height")

    parameters do
      height(:path, :integer, "Blockchain height", required: true)
    end

    response(200, "", %{})
  end

  def reward_at_height(conn, _params) do
    json(conn, @reward_at_height)
  end

  swagger_path :height_by_time do
    get("/height/at/{milliseconds}")
    description("Get block height at a given time(provided in milliseconds)")
    produces(["application/json"])
    deprecated(false)
    operation_id("height_by_time")

    parameters do
      milliseconds(:path, :integer, "Time in milliseconds", required: true)
    end

    response(200, "", %{})
  end

  def height_by_time(conn, _params) do
    json(conn, @height_by_time)
  end
end
