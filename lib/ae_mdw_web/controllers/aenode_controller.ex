defmodule AeMdwWeb.AeNodeController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias :aeser_api_encoder, as: Enc

  # Hardcoded DB only for testing purpose
  @tx_by_hash %{
    "block_hash" => "mh_MTNTqxHzknFa74v6zekKBrw5X1QgYnesxidzd8tts6dEaHog7",
    "block_height" => 226_184,
    "hash" => "th_ZvJbxoQjSjFeNTmpf2wgMRXmz1HQhi2BVKY1j3hzsBeBR1cYY",
    "signatures" => [
      "sg_jctC2NByGcAj45TnD3DvvGUmp4Jdr75JTjPUaUB3SEUbC879zvG87vCDtCEeicASmANEse6RiQtJTxYcAdjLuSpGnp43"
    ],
    "tx" => %{
      "amount" => 20000,
      "fee" => 19_320_000_000_000,
      "nonce" => 1_578_551,
      "payload" =>
        "ba_MjI2MTg2OmtoX25tdnM2VVBqNnBtcnl6ckhBV0dvd281S041dkVjVkEyblRFeDZGYXk3VjJlOVNkR1Y6bWhfMmdzVDdYM2JCVHhjZjlYRzROWW5yekdCREtxTG9nR1VQVVVwalVrVnB0c0NKRnpCUUo6MTU4NDIxMDY2N+QC5HQ=",
      "recipient_id" => "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
      "sender_id" => "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
      "ttl" => 226_196,
      "type" => "SpendTx",
      "version" => 1
    }
  }

  @get_account_details %{
    "balance" => 13_700_075_966_340_000_000_000,
    "id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
    "kind" => "basic",
    "nonce" => 2,
    "payable" => true
  }

  @current_key_block_height %{"height" => 226_189}

  def tx_by_hash(conn, %{"hash" => tx_hash}) do
    case :aeser_api_encoder.safe_decode(:tx_hash, tx_hash) do
      {:ok, hash} ->
        case :aec_chain.find_tx_with_location(hash) do
          :none ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Transaction not found"})

          {:mempool, tx} ->
            json(conn, :aetx_sign.serialize_for_client_pending(tx))

          {block_hash, tx} ->
            {:ok, header} = :aec_chain.get_header(block_hash)
            json(conn, :aetx_sign.serialize_for_client(header, tx))
        end

      {error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid hash"})
    end
  end

  def get_account_details(conn, %{"account" => account}) do
    allowed_types = [:account_pubkey, :contract_pubkey]
    case Validate.id(account, allowed_types) do
      {:ok, pk} ->
        case :aec_chain.get_account(pk) do
          {:value, account} ->
            json(conn, :aec_accounts.serialize_for_client(account))

          :none ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Account not found"})
        end
      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def current_key_block_height(conn, _params) do
    top_block = :aec_chain.top_block()
    height = :aec_blocks.height(top_block)
    json(conn, %{"height" => height})
  end

  def current_generations(conn, _params) do
    :aec_chain.get_current_generation() |> generation_rsp(conn)
  end

  def generation_by_height(conn, %{"height" => height}) do
    height = String.to_integer(height)

    case :aec_chain_state.get_key_block_hash_at_height(height) do
      :error ->
        conn |> put_status(:not_found) |> json(%{"reason" => "Chain too short"})

      {:ok, hash} ->
        hash
        |> :aec_chain.get_generation_by_hash(:forward)
        |> generation_rsp(conn)
    end
  end

  def key_block_by_hash(conn, %{"hash" => hash}) do
    case :aeser_api_encoder.safe_decode(:key_block_hash, hash) do
      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid hash"})

      {:ok, hash} ->
        case :aec_chain.get_block(hash) do
          {:ok, block} ->
            case :aec_blocks.is_key_block(block) do
              true ->
                header = :aec_blocks.to_header(block)

                case :aec_blocks.height(block) do
                  0 ->
                    json(conn, :aec_headers.serialize_for_client(header, :key))

                  _ ->
                    prev_block_hash = :aec_blocks.prev_hash(block)

                    case :aec_chain.get_block(prev_block_hash) do
                      {:ok, prev_block} ->
                        prev_block_type = :aec_blocks.type(prev_block)
                        json(conn, :aec_headers.serialize_for_client(header, prev_block_type))

                      :error ->
                        conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
                    end
                end

              false ->
                conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
            end

          :error ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
        end
    end
  end

  def key_block_by_height(conn, %{"height" => height}) do
    height = String.to_integer(height)

    case :aec_chain.get_key_block_by_height(height) do
      {:ok, block} ->
        header = :aec_blocks.to_header(block)

        case :aec_blocks.height(block) do
          0 ->
            json(conn, :aec_headers.serialize_for_client(header, :key))

          _ ->
            prev_block_hash = :aec_blocks.prev_hash(block)

            case :aec_chain.get_block(prev_block_hash) do
              {:ok, prev_block} ->
                prev_block_type = :aec_blocks.type(prev_block)
                json(conn, :aec_headers.serialize_for_client(header, prev_block_type))

              :error ->
                conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
            end
        end

      {:error, _rsn} ->
        conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
    end
  end

  def micro_block_header_by_hash(conn, %{"hash" => hash}) do
    case :aeser_api_encoder.safe_decode(:micro_block_hash, hash) do
      {:ok, hash} ->
        case :aehttp_logic.get_micro_block_by_hash(hash) do
          {:ok, block} ->
            prev_block_hash = :aec_blocks.prev_hash(block)

            case :aec_chain.get_block(prev_block_hash) do
              {:ok, prev_block} ->
                prev_block_type = :aec_blocks.type(prev_block)
                header = :aec_blocks.to_header(block)
                json(conn, :aec_headers.serialize_for_client(header, prev_block_type))

              :error ->
                conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
            end

          {:error, :block_not_found} ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
        end

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid hash"})
    end
  end

  def micro_block_transactions_by_hash(conn, %{"hash" => hash}) do
    case :aeser_api_encoder.safe_decode(:micro_block_hash, hash) do
      {:ok, hash} ->
        case :aehttp_logic.get_micro_block_by_hash(hash) do
          {:ok, block} ->
            header = :aec_blocks.to_header(block)

            txs =
              for tx <- :aec_blocks.txs(block), do: :aetx_sign.serialize_for_client(header, tx)

            json(conn, %{"transactions" => txs})

          {:error, :block_not_found} ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
        end

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid hash"})
    end
  end

  def micro_block_transactions_count_by_hash(conn, %{"hash" => hash}) do
    case :aeser_api_encoder.safe_decode(:micro_block_hash, hash) do
      {:ok, hash} ->
        case :aehttp_logic.get_micro_block_by_hash(hash) do
          {:ok, block} ->
            json(conn, %{"count" => length(:aec_blocks.txs(block))})

          {:error, :block_not_found} ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
        end

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid hash"})
    end
  end

  # ================================================

  defp generation_rsp(:error, conn) do
    conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
  end

  defp generation_rsp({:ok, %{key_block: key_block, micro_blocks: micro_blocks}}, conn) do
    case :aec_blocks.height(key_block) do
      0 ->
        json(conn, encode_generation(key_block, micro_blocks, :key))

      _ ->
        prev_block_hash = :aec_blocks.prev_hash(key_block)

        case :aec_chain.get_block(prev_block_hash) do
          {:ok, prev_block} ->
            prev_block_type = :aec_blocks.type(prev_block)
            json(conn, encode_generation(key_block, micro_blocks, prev_block_type))

          :error ->
            conn |> put_status(:not_found) |> json(%{"reason" => "Block not found"})
        end
    end
  end

  defp encode_generation(key_block, micro_blocks, prev_block_type) do
    header = :aec_blocks.to_header(key_block)

    %{
      key_block: :aec_headers.serialize_for_client(header, prev_block_type),
      micro_blocks:
        for micro_block <- micro_blocks do
          {:ok, hash} = :aec_blocks.hash_internal_representation(micro_block)
          :aeser_api_encoder.encode(:micro_block_hash, hash)
        end
    }
  end
end
