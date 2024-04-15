defmodule AeMdwWeb.CallsView do
  @moduledoc false

  alias AeMdw.Contracts

  @spec render_call(Contracts.call(), boolean()) :: Contracts.call()
  def render_call(call, v3?) do
    if v3? do
      Map.drop(call, [:call_txi, :contract_txi])
    else
      call
    end
  end
end
