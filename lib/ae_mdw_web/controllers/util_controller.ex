defmodule AeMdwWeb.UtilController do
  use AeMdwWeb, :controller

  # Hardcoded DB only for testing purpose
  # @status %{
  #   "OK" => true,
  #   "errors_last_500_blocks" => 3,
  #   "queue_length" => 0,
  #   "seconds_since_last_block" => 52,
  #   "version" => "0.13.0"
  # }

  # @current_count %{
  #   "count" => 8_783_720
  # }

  # @height_at_epoch %{
  #   "height" => 219_764
  # }

  # @reward_at_height %{
  #   "beneficiary" => "ak_nv5B93FPzRHrGNmMdTDfGdd5xGZvep3MVSpJqzcQmMp59bBCv",
  #   "coinbase" => "8085815189194932224",
  #   "fees" => "154584000000000",
  #   "height" => 224_190,
  #   "total" => "8085969773194932224"
  # }

  # @current_size %{
  #   "size" => 3_264_432_510
  # }
  # @size %{
  #   "size" => 3_260_992_358
  # }

  # @height %{"height" => 226_189}

  def status(conn, _params) do
    {:ok, top_kb} = :aec_chain.top_key_block()
    {_, _, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)
    status = %{node_version: to_string(node_vsn),
               node_height: :aec_blocks.height(top_kb),
               mdw_version: AeMdw.MixProject.project[:version],
               mdw_height: AeMdw.Db.Util.last_gen()}
    json(conn, status)
  end

  # def current_count(conn, _params) do
  #   json(conn, @current_count)
  # end

  # def size(conn, _params) do
  #   json(conn, @size)
  # end

  # def current_size(conn, _params) do
  #   json(conn, @current_size)
  # end

  # def reward_at_height(conn, _params) do
  #   json(conn, @reward_at_height)
  # end

  # def height_at_epoch(conn, _params) do
  #   json(conn, @height_at_epoch)
  # end

end
