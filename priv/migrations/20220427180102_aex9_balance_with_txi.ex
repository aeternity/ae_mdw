defmodule AeMdw.Migrations.Aex9BalanceWithTxi do
  @moduledoc """
  Adds txi to aex9 balances.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.WriteTxnMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Log

  require Model

  import AeMdw.Db.Util, only: [read_tx!: 1]

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    mutations =
      Model.Aex9Balance
      |> Collection.stream({<<>>, <<>>})
      |> Stream.map(fn {contract_pk, _account_pk} = key ->
        m_balance =
          Model.aex9_balance(block_index: bi, txi: txi) =
          case Database.fetch!(Model.Aex9Balance, key) do
            {:aex9_balance, ^key, bi, amount} ->
              Model.aex9_balance(index: key, block_index: bi, amount: amount)

            Model.aex9_balance(index: ^key) = m_balance ->
              m_balance
          end

        create_txi = Origin.tx_index!({:contract, contract_pk})
        bi = bi || Model.tx(read_tx!(create_txi), :block_index)
        txi = txi || create_txi
        txi = if txi == -1, do: create_txi, else: txi

        WriteTxnMutation.new(
          Model.Aex9Balance,
          Model.aex9_balance(m_balance, block_index: bi, txi: txi)
        )
      end)
      |> Enum.to_list()

    Database.commit(mutations)

    indexed_count = length(mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
