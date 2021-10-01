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

    header = :aec_db.get_header(block_hash)
    %{"tx" => tx} = :aetx_sign.serialize_for_client(header, signed_tx)

    raw = %{
      block_hash: :aeser_api_encoder.encode(:micro_block_hash, block_hash),
      signatures:
        Enum.map(:aetx_sign.signatures(signed_tx), &:aeser_api_encoder.encode(:signature, &1)),
      hash: :aeser_api_encoder.encode(:tx_hash, tx_hash),
      block_height: kb_index,
      micro_index: mb_index,
      micro_time: mb_time,
      tx_index: tx_index,
      tx: tx
    }

    type
    |> Format.custom_raw_data(raw, tx_rec, signed_tx, block_hash)
    |> update_if_present([:tx, :name_id], &render_id/1)
  end

  defp render_id({:id, id_type, payload}) do
    :aeser_api_encoder.encode(Node.id_type(id_type), payload)
  end

  defp render_id(id), do: id

  defp update_if_present(map, key_path, fun) do
    case get_in(map, key_path) do
      nil -> map
      val -> put_in(map, key_path, fun.(val))
    end
  end
end
