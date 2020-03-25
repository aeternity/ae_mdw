defmodule AeMdw.Db.Sync.ForkDetector do
  @moduledoc "detects only key forks at the moment"

  use GenServer

  import AeMdw.Util

  ################################################################################

  def start_link(_),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    :aec_events.subscribe(:top_changed)
    {:ok, nil}
  end

  def handle_info({_, :top_changed, %{info: %{block_type: :key, height: h}}}, s) do
    case headers(h, :key) do
      [_, _ | _] = candidates ->
        {main_header, _} = main_header(candidates)
        :aec_events.publish(:chain, {:fork, main_header})

      [header] ->
        :aec_events.publish(:chain, {:generation, header})
    end

    {:noreply, s}
  end

  def handle_info({_, :top_changed, %{info: %{block_type: :micro}}}, s),
    do: {:noreply, s}

  def headers(h, type) when is_integer(h),
    do: :aec_db.find_headers_at_height(h) |> Enum.filter(&(:aec_headers.type(&1) == type))

  def main_header(candidates) do
    candidates
    |> Stream.map(&{&1, ok!(:aec_headers.hash_header(&1))})
    |> Enum.reduce_while(
      nil,
      fn {header, hash}, nil ->
        # COSTLY!
        case :aec_chain_state.hash_is_in_main_chain(hash) do
          true -> {:halt, {header, hash}}
          false -> {:cont, nil}
        end
      end
    )
  end
end
