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
    [
      {HardforkPresets.hardfork_height(:genesis), HardforkPresets.mint_sum(:genesis)},
      {HardforkPresets.hardfork_height(:minerva), HardforkPresets.mint_sum(:minerva)},
      {HardforkPresets.hardfork_height(:fortuna), HardforkPresets.mint_sum(:fortuna)},
      {HardforkPresets.hardfork_height(:lima), HardforkPresets.mint_sum(:lima)}
    ]
  end
end
