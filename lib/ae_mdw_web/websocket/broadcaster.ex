defmodule AeMdwWeb.Websocket.Broadcaster do
  @moduledoc """
  Publishes Node and Middleware sync events to subscriptions.
  """
  use GenServer

  alias AeMdw.EtsCache

  require Ex2ms

  @dialyzer {:no_return, broadcast: 2}

  @hashes_table :broadcast_hashes
  @expiration_minutes 120
  @subs_target_channels :subs_target_channels

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok), do: {:ok, :no_state}

  @spec ets_config() :: {EtsCache.table(), EtsCache.expiration()}
  def ets_config(), do: {@hashes_table, @expiration_minutes}

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
  def handle_cast({:broadcast_key_block, block, source}, state) do
    {:ok, hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    if not already_processed?({:key, hash, source}) do
      do_broadcast_key_block(block, source)
    end

    push_hash({:key, hash, source})

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_micro_block, block, source}, state) do
    {:ok, hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    if not already_processed?({:micro, hash, source}) do
      do_broadcast_micro_block(block, source)
    end

    push_hash({:micro, hash, source})

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_txs, block, source}, state) do
    {:ok, hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    if not already_processed?({:txs, hash, source}) do
      do_broadcast_txs(block, source)
    end

    push_hash({:txs, hash, source})

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:broadcast_objects, header, tx, source}, state) do
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

    {:noreply, state}
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

  defp encode_message(payload, "Transactions", source),
    do:
      Poison.encode!(%{
        "payload" => encode_payload(payload),
        "subscription" => "Transactions",
        "source" => source
      })

  defp encode_message(payload, sub, source),
    do: Poison.encode!(%{"payload" => payload, "subscription" => sub, "source" => source})

  defp encode_payload(%{"tx" => %{"type" => "NameUpdateTx"}} = block_tx) do
    encode_name_pointers(block_tx)
  end

  defp encode_payload(
         %{"tx" => %{"type" => "GAMetaTx", "tx" => %{"tx" => %{"type" => "NameUpdateTx"}}}} =
           block_tx
       ) do
    encode_gameta_inner(block_tx, &encode_name_pointers/2)
  end

  defp encode_payload(%{"tx" => %{"type" => "OracleRegisterTx"}} = block_tx) do
    encode_oracle_register(block_tx)
  end

  defp encode_payload(
         %{"tx" => %{"type" => "GAMetaTx", "tx" => %{"tx" => %{"type" => "OracleRegisterTx"}}}} =
           block_tx
       ) do
    encode_gameta_inner(block_tx, &encode_oracle_register/2)
  end

  defp encode_payload(%{"tx" => %{"type" => "OracleQueryTx"}} = block_tx) do
    encode_oracle_query(block_tx)
  end

  defp encode_payload(
         %{"tx" => %{"type" => "GAMetaTx", "tx" => %{"tx" => %{"type" => "OracleQueryTx"}}}} =
           block_tx
       ) do
    encode_gameta_inner(block_tx, &encode_oracle_query/2)
  end

  defp encode_payload(block_tx), do: block_tx

  defp encode_name_pointers(block_tx, gameta_keys \\ []) do
    update_in(block_tx, gameta_keys ++ ["tx", "pointers"], fn pointers ->
      Enum.map(pointers, &encode_pointer/1)
    end)
  end

  defp encode_pointer(ptr), do: Map.update(ptr, "key", "", &Base.encode64/1)

  defp encode_oracle_register(block_tx, gameta_keys \\ []) do
    block_tx
    |> update_in(gameta_keys ++ ["tx", "query_format"], &Base.encode64/1)
    |> update_in(gameta_keys ++ ["tx", "response_format"], &Base.encode64/1)
  end

  defp encode_oracle_query(block_tx, gameta_keys \\ []) do
    update_in(block_tx, gameta_keys ++ ["tx", "query"], &Base.encode64/1)
  end

  defp encode_gameta_inner(block_tx, encode_fn) do
    encode_fn.(block_tx, ["tx", "tx"])
  end

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

  defp already_processed?(type_hash), do: EtsCache.get(@hashes_table, type_hash) != nil

  defp push_hash(type_hash), do: EtsCache.put(@hashes_table, type_hash, :ok)
end
