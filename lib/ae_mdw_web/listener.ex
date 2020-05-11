defmodule AeMdwWeb.Listener do
  use GenServer

  alias AeMdwWeb.Websocket.EtsManager, as: Ets
  require Ex2ms

  @subs_channel_targets :subs_channel_targets
  @subs_target_channels :subs_target_channels
  @main :main
  @sub :sub

  def start_link(_args), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def register(pid), do: GenServer.cast(__MODULE__, {:monitor, pid})

  def init(state) do
    @sub
    |> Ets.foldl([], fn {k, _v}, acc -> [k | acc] end)
    |> Enum.each(&register/1)

    :aec_events.subscribe(:top_changed)
    {:ok, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro} = info}}, state) do
    get_micro_blocks(info)
    get_txs(info, state)
    {:noreply, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :key} = info}}, state) do
    get_key_blocks(info)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    case Ets.is_member?(@main, pid) do
      true ->
        # main socket channel dies, all connections are disconnected. Clean all tables.
        Ets.delete_all_objects_in_all_tables([
          @subs_channel_targets,
          @subs_target_channels,
          @sub,
          @main
        ])

      false ->
        spec =
          Ex2ms.fun do
            {{^pid, sub}, _} -> sub
          end

        for sub <- Ets.select(@subs_channel_targets, spec) do
          key_to_delete = {sub, pid}
          Ets.delete(@subs_target_channels, key_to_delete)
        end

        spec_ =
          Ex2ms.fun do
            {{^pid, _}, _} -> true
          end

        Ets.select_delete(@subs_channel_targets, spec_)
        Ets.delete(@sub, pid)
    end

    {:noreply, state}
  end

  def handle_cast({:monitor, pid}, state) do
    Process.monitor(pid)
    {:noreply, state}
  end

  def get_txs(info, state) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        block
        |> :aec_blocks.txs()
        |> Enum.each(fn tx ->
          ser_tx = :aetx_sign.serialize_for_client(header, tx)
          broadcast("Transactions", data(ser_tx, "Transactions"))

          tx
          |> get_ids_from_tx()
          |> Enum.each(fn key ->
            spec =
              Ex2ms.fun do
                {{^key, _}, _} -> true
              end

            if Ets.select_count(@subs_target_channels, spec) != 0,
              do: broadcast(key, data(ser_tx, "Object"))
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
