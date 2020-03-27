defmodule AeMdwWeb.ContinuationData do
  @moduledoc """
  Building ContinuationData structure
  """
  alias AeMdwWeb.ContinuationData

  defstruct [:endpoint, :continuation, :page, :limit, :timestamp]

  @type t :: %ContinuationData{
          endpoint: List.t(),
          continuation: StreamSplit.t(),
          page: integer(),
          limit: integer(),
          timestamp: integer()
        }

  @spec create(List.t(), StreamSplit.t(), integer(), integer()) :: ContinuationData.t()
  def create(endpoint, continuation, page, limit) do
    %ContinuationData{
      endpoint: endpoint,
      continuation: continuation,
      page: page,
      limit: limit,
      timestamp: :os.system_time(:millisecond)
    }
  end
end
