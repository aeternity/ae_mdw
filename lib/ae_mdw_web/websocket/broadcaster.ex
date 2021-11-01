defmodule AeMdwWeb.Websocket.Broadcaster do
  @moduledoc """
  Publishes Node and Middleware sync events to subscriptions.
  """
  use GenServer

  require Ex2ms

  @dialyzer {:no_return, broadcast: 2}

  @no_state %{}
  @subs_target_channels :subs_target_channels

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    {:ok, @no_state}
  end

  @spec broadcast_key_block(tuple(), :node | :mdw) :: :ok
  def broadcast_key_block(block, source) do
    GenServer.cast(__MODULE__, {:broadcast_key_block, block, source})
  end

  @spec broadcast_micro_block(tuple(), :node | :mdw) :: :ok
  def broadcast_micro_block(block, source) do
    GenServer.cast(__MODULE__, {:broadcast_micro_block, block, source})
  end

  @spec broadcast_txs(tuple(), :node | :mdw) :: :ok
  def broadcast_txs(block, source) do
    GenServer.cast(__MODULE__, {:broadcast_txs, block, source})
  end

  @impl GenServer
  def handle_cast({:broadcast_key_block, block, source}, _state) do
    do_broadcast_key_block(block, source)
    {:noreply, @no_state}
  end

  @impl GenServer
  def handle_cast({:broadcast_micro_block, block, source}, _state) do
    do_broadcast_micro_block(block, source)
    {:noreply, @no_state}
  end

  @impl GenServer
  def handle_cast({:broadcast_txs, block, source}, _state) do
    do_broadcast_txs(block, source)
    {:noreply, @no_state}
  end

  @impl GenServer
  def handle_info({:broadcast_objects, header, tx, source}, _state) do
    ser_tx = :aetx_sign.serialize_for_client(header, tx)

    tx
    |> get_ids_from_tx()
    |> Enum.each(fn key ->
      spec =
        Ex2ms.fun do
          {{^key, _}, _} -> true
        end

      case :ets.select(@subs_target_channels, spec, 1) do
        :"$end_of_table" -> :ok
        {[_], _cont} -> broadcast(key, encode_message(ser_tx, "Object", source))
      end
    end)

    {:noreply, @no_state}
  end

  #
  # Private functions
  #
  defp do_broadcast_key_block(block, source) do
    header = :aec_blocks.to_header(block)

    if :aec_blocks.height(block) == 0 do
      msg =
        header
        |> :aec_headers.serialize_for_client(:key)
        |> encode_message("KeyBlocks", source)

      broadcast("KeyBlocks", msg)
    else
      prev_block_hash = :aec_blocks.prev_hash(block)

      case :aec_chain.get_block(prev_block_hash) do
        {:ok, prev_block} ->
          prev_block_type = :aec_blocks.type(prev_block)

          msg =
            header
            |> :aec_headers.serialize_for_client(prev_block_type)
            |> encode_message("KeyBlocks", source)

          broadcast("KeyBlocks", msg)
          :ok

        :error ->
          {:error, :block_not_found}
      end
    end
  end

  defp do_broadcast_micro_block(block, source) do
    prev_block_hash = :aec_blocks.prev_hash(block)

    case :aec_chain.get_block(prev_block_hash) do
      {:ok, prev_block} ->
        prev_block_type = :aec_blocks.type(prev_block)

        msg =
          block
          |> :aec_blocks.to_header()
          |> :aec_headers.serialize_for_client(prev_block_type)
          |> encode_message("MicroBlocks", source)

        broadcast("MicroBlocks", msg)
        :ok

      :error ->
        {:error, :block_not_found}
    end
  end

  defp do_broadcast_txs(block, source) do
    header = :aec_blocks.to_header(block)

    block
    |> :aec_blocks.txs()
    |> Enum.each(fn tx ->
      # sends Objects in separate message as broadcast has not_return
      Process.send(__MODULE__, {:broadcast_objects, header, tx, source}, [:noconnect])

      msg =
        header
        |> :aetx_sign.serialize_for_client(tx)
        |> encode_message("Transactions", source)

      broadcast("Transactions", msg)
    end)
  end

  defp broadcast(channel, msg) do
    Riverside.LocalDelivery.deliver(
      {:channel, channel},
      {:text, msg}
    )
  end

  defp encode_message(payload, sub, source),
    do: Poison.encode!(%{"payload" => payload, "subscription" => sub, "source" => source})

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
