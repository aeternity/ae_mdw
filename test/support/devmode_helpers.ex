defmodule AeMdw.DevmodeHelpers do
  @moduledoc false

  @output_file "./node_sdk/output.json"

  @spec output() :: map()
  def output do
    @output_file
    |> File.read!()
    |> Jason.decode!()
  end
end
