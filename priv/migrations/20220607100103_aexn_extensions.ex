defmodule AeMdw.Migrations.AddAexnExtensions do
  @moduledoc """
  Add extensions to AEX-N contracts.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    aexn_pubkeys = Database.all_keys(Model.AexnContract)

    aexn_mutations =
      aexn_pubkeys
      |> Enum.map(&add_extensions/1)
      |> Enum.reject(&is_nil/1)

    State.commit(State.new(), aexn_mutations)

    indexed_count = length(aexn_mutations)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp add_extensions({aexn_type, pubkey} = aexn_key) do
    with {:ok, {:aexn_contract, ^aexn_key, txi, meta_info}} <-
           Database.fetch(Model.AexnContract, aexn_key),
         {:ok, extensions} <- AexnContracts.call_extensions(aexn_type, pubkey) do
      m_aexn =
        Model.aexn_contract(
          index: aexn_key,
          txi: txi,
          meta_info: meta_info,
          extensions: extensions
        )

      WriteMutation.new(Model.AexnContract, m_aexn)
    else
      _not_found_or_error_ -> nil
    end
  end
end
