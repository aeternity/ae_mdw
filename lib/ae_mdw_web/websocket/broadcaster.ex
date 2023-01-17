defmodule AeMdwWeb.Websocket.Broadcaster do
  @moduledoc """
  Publishes Node and Middleware sync events to subscriptions.
  """
  use GenServer

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.EtsCache
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdwWeb.Websocket.Subscriptions
  alias AeMdwWeb.Websocket.SocketHandler

  require Ex2ms

  @hashes_table :broadcast_hashes
  @expiration_minutes 120

  @typep source() :: :node | :mdw
  @typep version() :: Subscriptions.version()

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok), do: {:ok, :no_state}

  @spec ets_config() :: {EtsCache.table(), EtsCache.expiration()}
  def ets_config(), do: {@hashes_table, @expiration_minutes}

  @spec broadcast_key_block(Db.key_block(), version(), source()) :: :ok
  def broadcast_key_block(block, version, source) do
    header = :aec_blocks.to_header(block)
    {:ok, hash} = :aec_headers.hash_header(header)

    if not already_processed?({:key, version, hash, source}) do
      GenServer.cast(__MODULE__, {:broadcast_key_block, version, header, source})
      set_processed({:key, version, hash, source})
    end

    :ok
  end

  @spec broadcast_micro_block(Db.micro_block(), version(), source()) :: :ok
  def broadcast_micro_block(block, version, source) do
    header = :aec_blocks.to_header(block)
    {:ok, hash} = :aec_headers.hash_header(header)

    if not already_processed?({:micro, version, hash, source}) do
      GenServer.cast(__MODULE__, {:broadcast_micro_block, version, header, source})
      set_processed({:micro, version, hash, source})
    end

    :ok
  end

  @spec broadcast_txs(Db.micro_block(), version(), source()) :: :ok
  def broadcast_txs(block, version, source) do
    {:ok, hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    if not already_processed?({:txs, version, hash, source}) &&
         (Subscriptions.has_subscribers(version, "Transactions") ||
            Subscriptions.has_object_subscribers(version)) do
      GenServer.cast(__MODULE__, {:broadcast_txs, version, block, source})
      set_processed({:txs, version, hash, source})
    end

    :ok
  end

  @impl GenServer
  def handle_cast({:broadcast_key_block, version, header, source}, state) do
    do_broadcast_key_block(header, version, source)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_micro_block, version, header, source}, state) do
    do_broadcast_micro_block(header, version, source)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_txs, version, block, source}, state) do
    do_broadcast_txs(block, version, source)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  #
  # Private functions
  #
  defp do_broadcast_key_block(header, :v2, :mdw) do
    height = :aec_headers.height(header)
    state = State.mem_state()

    case Blocks.fetch_key_block(state, "#{height}") do
      {:ok, block} ->
        msg = encode_message(block, "KeyBlocks", block)
        broadcast("KeyBlocks", :v2, msg)

      {:error, _reason} ->
        :ok
    end
  end

  defp do_broadcast_key_block(header, version, source) do
    prev_block_type = Db.prev_block_type(header)

    msg =
      header
      |> :aec_headers.serialize_for_client(prev_block_type)
      |> encode_message("KeyBlocks", source)

    broadcast("KeyBlocks", version, msg)
  end

  defp do_broadcast_micro_block(header, :v2, :mdw) do
    {:ok, hash} = :aec_headers.hash_header(header)
    state = State.mem_state()

    case Blocks.fetch_micro_block(state, hash) do
      {:ok, block} ->
        msg = encode_message(block, "MicroBlocks", block)
        broadcast("MicroBlocks", :v2, msg)

      {:error, _reason} ->
        :ok
    end
  end

  defp do_broadcast_micro_block(header, version, source) do
    prev_block_type = Db.prev_block_type(header)

    msg =
      header
      |> :aec_headers.serialize_for_client(prev_block_type)
      |> encode_message("MicroBlocks", source)

    broadcast("MicroBlocks", version, msg)
  end

  defp do_broadcast_txs(block, :v2, :mdw) do
    state = State.mem_state()

    block
    |> :aec_blocks.txs()
    |> Enum.each(fn tx ->
      tx_hash = :aetx_sign.hash(tx)

      case Txs.fetch(state, tx_hash, true) do
        {:ok, mdw_tx} ->
          mdw_msg = encode_message(mdw_tx, "Transactions", :mdw)
          broadcast("Transactions", :v2, mdw_msg)

          tx
          |> get_ids_from_tx()
          |> Enum.each(&broadcast(&1, :v2, encode_message(mdw_tx, "Object", :mdw)))

        {:error, _reason} ->
          :ok
      end
    end)
  end

  defp do_broadcast_txs(block, version, source) do
    header = :aec_blocks.to_header(block)

    block
    |> :aec_blocks.txs()
    |> Enum.each(fn tx ->
      ser_tx = :aetx_sign.serialize_for_client(header, tx)

      msg =
        header
        |> :aetx_sign.serialize_for_client(tx)
        |> encode_message("Transactions", source)

      broadcast("Transactions", version, msg)

      tx
      |> get_ids_from_tx()
      |> Enum.each(&broadcast(&1, version, encode_message(ser_tx, "Object", source)))
    end)
  end

  defp broadcast(channel, version, msg) do
    version
    |> Subscriptions.subscribers(channel)
    |> Enum.each(&SocketHandler.send(&1, msg))
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

  defp already_processed?(type_hash), do: EtsCache.member(@hashes_table, type_hash)

  defp set_processed(type_hash), do: EtsCache.put(@hashes_table, type_hash, true)
end
