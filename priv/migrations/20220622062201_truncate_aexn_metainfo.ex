defmodule AeMdw.Migrations.TruncateAexnMetainfo do
  @moduledoc """
  Truncates AEX-N meta-info sorting field (name and symbol) to a length of 100 chars.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model

  @max_sort_field_len 100

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    aexn_names = Database.all_keys(Model.AexnContractName)

    aexn_name_mutations =
      Enum.flat_map(aexn_names, fn key -> truncate_mutations(Model.AexnContractName, key) end)

    aexn_symbols = Database.all_keys(Model.AexnContractSymbol)

    aexn_symbol_mutations =
      Enum.flat_map(aexn_symbols, fn key -> truncate_mutations(Model.AexnContractSymbol, key) end)

    State.commit(State.new(), aexn_name_mutations ++ aexn_symbol_mutations)

    indexed_count = length(aexn_name_mutations ++ aexn_symbol_mutations)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp truncate_mutations(table, {aexn_type, field_value, pubkey} = aexn_sort_key) do
    if truncate?(field_value) do
      truncated_field = String.slice(field_value, 0, @max_sort_field_len) <> "..."
      m_record = {Model.record(table), {aexn_type, truncated_field, pubkey}, nil}

      [
        WriteMutation.new(table, m_record),
        DeleteKeysMutation.new(%{table => [aexn_sort_key]})
      ]
    else
      []
    end
  end

  defp truncate?(field_value) do
    is_binary(field_value) and not String.ends_with?(field_value, "...") and
      String.length(field_value) > @max_sort_field_len
  end
end
