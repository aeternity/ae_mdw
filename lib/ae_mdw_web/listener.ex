defmodule AeMdwWeb.Listener do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    :aec_events.subscribe(:top_changed)
    {:ok, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: info}}, state) do
    get_key_blocks(info)
    get_micro_blocks_header(info)
    get_txs(info)
    get_micro_blocks(info)
    {:noreply, state}
  end

  def get_txs(info) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        txs =
          for tx <- :aec_blocks.txs(block) do
            data = %{
              "payload" => :aetx_sign.serialize_for_client(header, tx),
              "subscription" => "Transactions"
            }

            Riverside.LocalDelivery.deliver(
              {:channel, "Transactions"},
              {:text, Poison.encode!(data)}
            )
          end

      {:error, :block_not_found} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end

  def get_micro_blocks_header(info) do
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

            Riverside.LocalDelivery.deliver(
              {:channel, "MicroBlocks"},
              {:text, Poison.encode!(data)}
            )

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

            Riverside.LocalDelivery.deliver(
              {:channel, "KeyBlocks"},
              {:text, Poison.encode!(data)}
            )

          _ ->
            prev_block_hash = :aec_blocks.prev_hash(block)

            case :aec_chain.get_block(prev_block_hash) do
              {:ok, prev_block} ->
                prev_block_type = :aec_blocks.type(prev_block)

                data = %{
                  "payload" => :aec_headers.serialize_for_client(header, prev_block_type),
                  "subscription" => "KeyBlocks"
                }

                Riverside.LocalDelivery.deliver(
                  {:channel, "KeyBlocks"},
                  {:text, Poison.encode!(data)}
                )

              :error ->
                {:error, %{"reason" => "Block not found"}}
            end
        end

      {:error, _rsn} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end

  def get_micro_blocks(info) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        txs =
          for tx <- :aec_blocks.txs(block) do
            :aetx_sign.serialize_for_client(header, tx)
          end

        prev_block_hash = :aec_blocks.prev_hash(block)

        case :aec_chain.get_block(prev_block_hash) do
          {:ok, prev_block} ->
            prev_block_type = :aec_blocks.type(prev_block)
            header = :aec_blocks.to_header(block)
            ser_header = :aec_headers.serialize_for_client(header, prev_block_type)

            data = Enum.reduce(txs, %{}, fn %{"hash" => v} = tx, acc -> Map.put(acc, v, tx) end)

            Riverside.LocalDelivery.deliver(
              {:channel, "MicroBlocks"},
              {:text, Poison.encode!(data)}
            )

          :error ->
            {:error, %{"reason" => "Block not found"}}
        end

      {:error, :block_not_found} ->
        {:error, %{"reason" => "Block not found"}}
    end
  end
end
