defmodule AeMdwWeb.Websocket.Broadcaster do
  @moduledoc """
  Publishes Node and Middleware sync events to subscriptions.
  """
  require Ex2ms

  @subs_target_channels :subs_target_channels

  @spec broadcast_key_block(:aec_blocks.block(), :node | :mdw) :: :ok | {:error, :block_not_found}
  def broadcast_key_block(block, source) do
    header = :aec_blocks.to_header(block)

    if :aec_blocks.height(block) == 0 do
      broadcast(
        "KeyBlocks",
        header
        |> :aec_headers.serialize_for_client(:key)
        |> data("KeyBlocks", source)
      )
    else
      prev_block_hash = :aec_blocks.prev_hash(block)

      case :aec_chain.get_block(prev_block_hash) do
        {:ok, prev_block} ->
          prev_block_type = :aec_blocks.type(prev_block)

          msg =
            header
            |> :aec_headers.serialize_for_client(prev_block_type)
            |> data("KeyBlocks", source)

          broadcast("KeyBlocks", msg)
          :ok

        :error ->
          {:error, :block_not_found}
      end
    end
  end

  @spec broadcast_micro_block(:aec_blocks.micro_block(), :node | :mdw) :: :ok | {:error, :block_not_found}
  def broadcast_micro_block(block, source) do
    prev_block_hash = :aec_blocks.prev_hash(block)

    case :aec_chain.get_block(prev_block_hash) do
      {:ok, prev_block} ->
        prev_block_type = :aec_blocks.type(prev_block)

        msg =
          block
          |> :aec_blocks.to_header()
          |> :aec_headers.serialize_for_client(prev_block_type)
          |> data("MicroBlocks", source)

        broadcast("MicroBlocks", msg)
        :ok

      :error ->
        {:error, :block_not_found}
    end
  end

  @spec broadcast_txs(:aec_blocks.micro_block(), :node | :mdw) :: :ok | {:error, :block_not_found}
  def broadcast_txs(block, source) do
    header = :aec_blocks.to_header(block)

    block
    |> :aec_blocks.txs()
    |> Enum.each(fn tx ->
      ser_tx = :aetx_sign.serialize_for_client(header, tx)
      broadcast("Transactions", data(ser_tx, "Transactions", source))

      tx
      |> get_ids_from_tx()
      |> Enum.each(fn key ->
        spec =
          Ex2ms.fun do
            {{^key, _}, _} -> true
          end

        case :ets.select(@subs_target_channels, spec, 1) do
          :"$end_of_table" -> :ok
          {[_], _cont} -> broadcast(key, data(ser_tx, "Object", source))
        end
      end)
    end)
  end

  defp broadcast(channel, msg) do
      Riverside.LocalDelivery.deliver(
        {:channel, channel},
        {:text, Poison.encode!(msg)}
      )
      :ok
  end

  defp data(data, sub, source),
    do: %{"payload" => data, "subscription" => sub, "source" => source}

  defp get_ids_from_tx(signed_tx) do
    wrapped_tx = :aetx_sign.tx(signed_tx)
    {tx_type, naked_tx} = :aetx.specialize_type(wrapped_tx)

    tx_type
    |> AeMdw.Node.tx_ids()
    |> Map.values()
    |> Enum.map(&elem(naked_tx, &1))
    |> Enum.map(&AeMdw.Validate.id!/1)
    |> Enum.uniq()
  end
end
