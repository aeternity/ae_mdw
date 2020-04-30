defmodule AeMdwWeb.Listener do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    :aec_events.subscribe(:top_changed)
    {:ok, state}
  end

  def new_object(target), do: GenServer.cast(__MODULE__, {:add, target})

  def remove_object(target), do: GenServer.cast(__MODULE__, {:remove, target})

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro} = info}}, state) do
    get_micro_blocks(info)
    get_txs(info, state)
    {:noreply, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :key} = info}}, state) do
    get_key_blocks(info)
    {:noreply, state}
  end

  def handle_cast({:add, target}, state), do: {:noreply, [target | state] |> Enum.uniq()}

  def handle_cast({:remove, target}, state), do: {:noreply, state -- [target]}

  def get_txs(info, state) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        Enum.each(:aec_blocks.txs(block), fn tx ->
          ser_tx = :aetx_sign.serialize_for_client(header, tx)
          broadcast("Transactions", data(ser_tx, "Transactions"))

          Enum.each(state, fn obj ->
            Enum.each(get_ids_from_tx(tx), fn key ->
              if key == obj do
                broadcast(obj, data(ser_tx, "Object"))
              end
            end)
          end)
        end)

      {:error, :block_not_found} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end

  def get_micro_blocks(info) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        prev_block_hash = :aec_blocks.prev_hash(block)

        case :aec_chain.get_block(prev_block_hash) do
          {:ok, prev_block} ->
            prev_block_type = :aec_blocks.type(prev_block)
            header = :aec_blocks.to_header(block)

            ser_tx = :aec_headers.serialize_for_client(header, prev_block_type)
            payload = Map.put(ser_tx, "key_block_id", ser_tx["height"])

            broadcast("MicroBlocks", data(payload, "MicroBlocks"))

          :error ->
            {:error, %{"reason" => "Block not found"}}
        end

      {:error, :block_not_found} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end

  def get_key_blocks(info) do
    case :aec_chain.get_key_block_by_height(info.height) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        case :aec_blocks.height(block) do
          0 ->
            broadcast(
              "KeyBlocks",
              header
              |> :aec_headers.serialize_for_client(:key)
              |> data("KeyBlocks")
            )

          _ ->
            prev_block_hash = :aec_blocks.prev_hash(block)

            case :aec_chain.get_block(prev_block_hash) do
              {:ok, prev_block} ->
                prev_block_type = :aec_blocks.type(prev_block)

                broadcast(
                  "KeyBlocks",
                  header
                  |> :aec_headers.serialize_for_client(prev_block_type)
                  |> data("KeyBlocks")
                )

              :error ->
                {:error, %{"reason" => "Block not found"}}
            end
        end

      {:error, _rsn} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end

  def broadcast(channel, msg),
    do:
      Riverside.LocalDelivery.deliver(
        {:channel, channel},
        {:text, Poison.encode!(msg)}
      )

  def data(data, sub), do: %{"payload" => data, "subscription" => sub}

  def get_ids_from_tx(tx) do
    wrapped_tx = :aetx_sign.tx(tx)
    {tx_type, naked_tx} = :aetx.specialize_type(wrapped_tx)

    tx_type
    |> AeMdw.Node.tx_ids()
    |> Map.values()
    |> Enum.map(&elem(naked_tx, &1))
    |> Enum.map(&AeMdw.Validate.id!/1)
    |> Enum.uniq()
  end
end
