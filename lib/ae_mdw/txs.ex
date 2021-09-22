defmodule AeMdw.Txs do
  @moduledoc """
  Context module for dealing with Transactions.
  """

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Node.Db

  require Model

  @type txi :: non_neg_integer()
  # This needs to be an actual type like AeMdw.Db.Tx.t()
  @type tx :: term()

  @table Model.Tx

  @spec fetch!(txi()) :: tx()
  def fetch!(txi) do
    {:ok, tx} = fetch(txi)

    tx
  end

  @spec fetch(txi()) :: {:ok, tx()} | :not_found
  def fetch(txi) do
    case Mnesia.fetch(@table, txi) do
      {:ok, tx} -> {:ok, render(tx)}
      :not_found -> :not_found
    end
  end

  defp render(
         Model.tx(index: tx_index, id: tx_hash, block_index: {kb_index, mb_index}, time: mb_time)
       ) do
    {block_hash, type, signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

    tx_map =
      tx_rec
      |> Format.to_raw_map(type)
      |> put_in([:type], type)

    raw = %{
      block_hash: block_hash,
      signatures: :aetx_sign.signatures(signed_tx),
      hash: tx_hash,
      block_height: kb_index,
      micro_index: mb_index,
      micro_time: mb_time,
      tx_index: tx_index,
      tx: tx_map
    }

    type
    |> Format.custom_raw_data(raw, tx_rec, signed_tx, block_hash)
    |> update_in([:tx, :account_id], &render_id/1)
    |> update_in([:tx, :name_id], &render_id/1)
    |> update_in([:tx, :recipient_id], &render_id/1)
  end

  defp render_id({:id, id_type, payload}) do
    :aeser_api_encoder.encode(Node.id_type(id_type), payload)
  end

  defp render_id(id), do: id
end
