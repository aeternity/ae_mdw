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

  def handle_cast({:add, target}, state), do: {:noreply, [target | state]}

  def handle_cast({:remove, target}, state), do: {:noreply, state -- [target]}

  def get_txs(info, state) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        txs =
          for tx <- :aec_blocks.txs(block) do
            ser_tx = :aetx_sign.serialize_for_client(header, tx)

            data = %{
              "payload" => ser_tx,
              "subscription" => "Transactions"
            }

            broadcast("Transactions", data)

            Enum.each(state, fn obj ->
              case ser_tx["tx"]["type"] do
                "SpendTx" ->
                  if ser_tx["tx"]["recipient_id"] == obj || ser_tx["tx"]["sender_id"] == obj do
                    data = %{
                      "payload" => :aetx_sign.serialize_for_client(header, tx),
                      "subscription" => "Object"
                    }

                    broadcast(obj, data)
                  end
              end
            end)
          end

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

            data = %{
              "payload" => :aec_headers.serialize_for_client(header, prev_block_type),
              "subscription" => "MicroBlocks"
            }

            broadcast("MicroBlocks", data)

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
            data = %{
              "payload" => :aec_headers.serialize_for_client(header, :key),
              "subscription" => "KeyBlocks"
            }

            broadcast("KeyBlocks", data)

          _ ->
            prev_block_hash = :aec_blocks.prev_hash(block)

            case :aec_chain.get_block(prev_block_hash) do
              {:ok, prev_block} ->
                prev_block_type = :aec_blocks.type(prev_block)

                data = %{
                  "payload" => :aec_headers.serialize_for_client(header, prev_block_type),
                  "subscription" => "KeyBlocks"
                }

                broadcast("KeyBlocks", data)

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
end
