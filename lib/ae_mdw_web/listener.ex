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

        Enum.each(:aec_blocks.txs(block), fn tx ->
          ser_tx = :aetx_sign.serialize_for_client(header, tx)
          type = ser_tx["tx"]["type"]

          Enum.each(state, fn obj ->
            broadcast_tx(type, obj, ser_tx)
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

  def broadcast_tx("SpendTx", obj, ser_tx) do
    if ser_tx["tx"]["recipient_id"] == obj || ser_tx["tx"]["sender_id"] == obj do
      broadcast(obj, data(ser_tx, "Object"))
    end
  end

  def broadcast_tx("OracleRegisterTx", obj, ser_tx) do
    if ser_tx["oracle_id"] == obj || ser_tx["tx"]["account_id"] == obj do
      broadcast(obj, data(ser_tx, "Object"))
    end
  end

  def broadcast_tx("OracleExtendTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("OracleQueryTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ContractCallTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ContractCreateTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelCreateTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelDepositTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelWithdrawTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelCloseMutualTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelForceProgressTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelCloseSoloTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelSlashTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelSettleTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("ChannelSnapshotSoloTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("NamePreclaimTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("NameClaimTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("NameUpdateTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("NameTransferTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("NameRevokeTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("GAAttachTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end

  def broadcast_tx("GAMetaTx", obj, ser_tx) do
    # TODO logic
    broadcast(obj, data(ser_tx, "Object"))
  end
end
