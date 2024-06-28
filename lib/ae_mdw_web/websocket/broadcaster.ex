defmodule AeMdwWeb.Websocket.Broadcaster do
  @moduledoc """
  Publishes Node and Middleware sync events to subscriptions.
  """
  use GenServer

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdwWeb.Websocket.Subscriptions
  alias AeMdwWeb.Websocket.SocketHandler

  import AeMdw.Util.Encoding, only: [encode: 2]
  import AeMdwWeb.Websocket.BroadcasterCache

  require Ex2ms

  @typep source :: :node | :mdw
  @typep version :: Subscriptions.version()
  @typep count :: integer() | nil

  @block_subs %{
    key: "KeyBlocks",
    micro: "MicroBlocks"
  }

  @versions [:v1, :v2, :v3]

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok), do: {:ok, :no_state}

  @spec broadcast_key_block(Db.key_block(), version(), source(), count(), count()) :: :ok
  def broadcast_key_block(block, version, source, mb_count, txs_count) do
    header = :aec_blocks.to_header(block)
    {:ok, hash} = :aec_headers.hash_header(header)

    if not already_processed?({:key, version, hash, source}) do
      if Subscriptions.has_subscribers?(source, version, "KeyBlocks") do
        GenServer.cast(
          __MODULE__,
          {:broadcast_key_block, header, source, version, mb_count, txs_count}
        )
      end

      set_processed({:key, version, hash, source})
    end

    :ok
  end

  @spec broadcast_micro_block(Db.micro_block(), source()) :: :ok
  def broadcast_micro_block(block, source) do
    header = :aec_blocks.to_header(block)
    {:ok, hash} = :aec_headers.hash_header(header)

    if not already_processed?({:micro, hash, source}) do
      versions = get_subscribed_versions("MicroBlocks", source)

      if Enum.any?(versions) do
        txs_count = length(:aec_blocks.txs(block))
        GenServer.cast(__MODULE__, {:broadcast_micro_block, header, source, versions, txs_count})
      end

      set_processed({:micro, hash, source})
    end

    :ok
  end

  @spec broadcast_txs(Db.micro_block(), source()) :: :ok
  def broadcast_txs(block, source) do
    {:ok, hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    if not already_processed?({:txs, hash, source}) do
      versions = Enum.filter(@versions, &broadcast_transaction?(source, &1))

      if Enum.any?(versions) do
        GenServer.cast(__MODULE__, {:broadcast_txs, block, source, versions})
      end

      set_processed({:txs, hash, source})
    end

    :ok
  end

  @impl GenServer
  def handle_cast({:broadcast_key_block, header, source, version, mbs_count, txs_count}, state) do
    _result =
      do_broadcast_block(header, source, version, %{
        micro_blocks_count: mbs_count,
        transactions_count: txs_count
      })

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_micro_block, header, source, versions, txs_count}, state) do
    Enum.each(versions, &do_broadcast_block(header, source, &1, %{transactions_count: txs_count}))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:broadcast_txs, micro_block, source, versions}, state) do
    Enum.each(versions, &do_broadcast_txs(micro_block, source, &1))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  #
  # Private functions
  #
  defp do_broadcast_block(header, source, version, counters) do
    type = :aec_headers.type(header)
    channel = Map.fetch!(@block_subs, type)

    with {:ok, block} <- serialize_block(header, type, source, version) do
      block
      |> Map.merge(counters)
      |> encode_message(channel, source)
      |> broadcast(channel, source, version)
    end
  end

  defp serialize_block(header, :key, :mdw, version) when version in [:v2, :v3] do
    height = header |> :aec_headers.height() |> Integer.to_string()
    Blocks.fetch_key_block(State.mem_state(), height)
  end

  defp serialize_block(header, :micro, :mdw, version) when version in [:v2, :v3] do
    {:ok, hash} = :aec_headers.hash_header(header)
    Blocks.fetch_micro_block(State.mem_state(), encode(:micro_block_hash, hash))
  end

  defp serialize_block(header, _type, _source, _version) do
    prev_block_type = Db.prev_block_type(header)
    {:ok, :aec_headers.serialize_for_client(header, prev_block_type)}
  end

  defp do_broadcast_txs(block, source, version) do
    tx_pids = Subscriptions.subscribers(source, version, "Transactions")

    context =
      if {source, version} in [{:mdw, :v2}, {:mdw, :v3}] do
        {:state, State.mem_state()}
      else
        {:block, block}
      end

    block
    |> :aec_blocks.txs()
    |> Enum.each(fn tx ->
      with {:ok, mdw_tx} <- serialize_tx(tx, context, version) do
        mdw_tx
        |> encode_message("Transactions", source)
        |> broadcast_tx(tx_pids)

        base_obj_msg = %{"payload" => mdw_tx, "subscription" => "Object", "source" => source}

        tx
        |> get_ids_from_tx()
        |> Enum.each(fn {:id, id_type, pubkey} ->
          id = id_type |> encode_type() |> encode(pubkey)

          base_obj_msg
          |> Map.put("target", id)
          |> Jason.encode!()
          |> broadcast(id, source, version)
        end)
      end
    end)
  end

  defp serialize_tx(tx, {:state, state}, version) do
    tx_hash = :aetx_sign.hash(tx)
    v3? = if version == :v3, do: true, else: false
    Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: v3?)
  end

  defp serialize_tx(tx, {:block, block}, _version) do
    {:ok,
     block
     |> :aec_blocks.to_header()
     |> :aetx_sign.serialize_for_client(tx)}
  end

  defp broadcast_tx(msg, pids) do
    Enum.each(pids, &SocketHandler.send(&1, msg))
  end

  defp broadcast(msg, channel, source, version) do
    source
    |> Subscriptions.subscribers(version, channel)
    |> Enum.each(&SocketHandler.send(&1, msg))
  end

  defp encode_message(payload, "Transactions", source),
    do:
      Jason.encode!(%{
        "payload" => encode_payload(payload),
        "subscription" => "Transactions",
        "source" => source
      })

  defp encode_message(payload, sub, source),
    do: Jason.encode!(%{"payload" => payload, "subscription" => sub, "source" => source})

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
    |> AeMdw.Node.tx_ids_positions()
    |> Enum.map(&elem(naked_tx, &1))
    |> Enum.uniq()
  end

  defp get_subscribed_versions(channel, source) do
    Enum.filter(@versions, &Subscriptions.has_subscribers?(source, &1, channel))
  end

  defp broadcast_transaction?(source, version) do
    Subscriptions.has_subscribers?(source, version, "Transactions") ||
      Subscriptions.has_object_subscribers?(source, version)
  end

  defp encode_type(:account), do: :account_pubkey
  defp encode_type(:contract), do: :contract_pubkey
  defp encode_type(:oracle), do: :oracle_pubkey
  defp encode_type(id_type), do: id_type
end
