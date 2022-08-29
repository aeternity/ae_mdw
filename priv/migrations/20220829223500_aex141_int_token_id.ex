defmodule AeMdw.Migrations.Aex141IntTokenId do
  @moduledoc """
  Converts AEX-141 to integer.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    updated_count =
      Model.NftOwnership
      |> Database.all_keys()
      |> Enum.map(fn
        {owner_pk, contract_pk, <<token_id::256>>} = key ->
          Database.dirty_write(
            Model.NftOwnership,
            Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
          )

          Database.dirty_delete(Model.NftOwnership, key)
          1

        _other_key ->
          0
      end)
      |> Enum.sum()

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {updated_count, duration}}
  end
end
