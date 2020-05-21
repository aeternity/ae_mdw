defmodule AeMdwWeb.Websocket.Listener do
  use GenServer

  require Ex2ms

  @subs_main :subs_main
  @subs_pids :subs_pids
  @subs_channel_targets :subs_channel_targets
  @subs_target_channels :subs_target_channels

  def start_link(arg), do: GenServer.start_link(__MODULE__, arg, name: __MODULE__)

  def register(pid), do: GenServer.cast(__MODULE__, {:monitor, pid})

  def init(:subs_events) do
    :ets.foldl(fn {k, _v}, acc -> [k | acc] end, [], @subs_pids) |> Enum.each(&register/1)
    :aec_events.subscribe(:top_changed)
    {:ok, []}
  end

   # for test purpose only
   def init(:no_events) do
    :ets.foldl(fn {k, _v}, acc -> [k | acc] end, [], @subs_pids) |> Enum.each(&register/1)
    {:ok, []}
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
    case :ets.member(@subs_main, pid) do
      true ->
        # main socket channel dies, all connections are disconnected. Clean all tables.
        Enum.each(
          [@subs_main, @subs_channel_targets, @subs_target_channels, @subs_pids],
          &:ets.delete_all_objects/1
        )

      false ->
        spec =
          Ex2ms.fun do
            {{^pid, sub}, _} -> sub
          end

        for sub <- :ets.select(@subs_channel_targets, spec) do
          key_to_delete = {sub, pid}
          :ets.delete(@subs_target_channels, key_to_delete)
        end

        spec_ =
          Ex2ms.fun do
            {{^pid, _}, _} -> true
          end

        :ets.select_delete(@subs_channel_targets, spec_)
        :ets.delete(@subs_pids, pid)
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

            case :ets.select(@subs_target_channels, spec, 1) do
              :"$end_of_table" -> :ok
              {[_], _cont} -> broadcast(key, data(ser_tx, "Object"))
            end
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

            broadcast(
              "MicroBlocks",
              header
              |> :aec_headers.serialize_for_client(prev_block_type)
              |> data("MicroBlocks")
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
