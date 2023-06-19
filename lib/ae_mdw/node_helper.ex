defmodule AeMdw.NodeHelper do
  @moduledoc """
  Actual functions called by SmartGlobal AeMdw.Node.
  """

  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Extract

  @spec record_keys(list(), atom()) :: [atom()]
  def record_keys(mod_code, rec_name) do
    {:ok, rec_code} = Extract.AbsCode.record_fields(mod_code, rec_name)
    Enum.map(rec_code, &elem(Extract.AbsCode.field_name_type(&1), 0))
  end

  @spec token_supply_delta() :: list()
  def token_supply_delta() do
    :aec_hard_forks.protocols()
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn proto ->
      proto_vsn = :aec_hard_forks.protocol_vsn_name(proto)
      {HardforkPresets.hardfork_height(proto_vsn), HardforkPresets.mint_sum(proto_vsn)}
    end)
  end
end
