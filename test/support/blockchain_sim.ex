defmodule AeMdwWeb.BlockchainSim do
  @moduledoc """
  """

  require Mock

  @passthrough_functions ~w(module_info)a

  @type account_id() :: :aeser_id.id()

  defmacro with_blockchain(initial_balances, blocks, do: body) do
    aec_db =
      :exports
      |> :aec_db.module_info()
      |> Enum.map(fn {fun_name, arity} ->
        args = Macro.generate_arguments(arity, __MODULE__)

        {fun_name,
         {:fn, [],
          quote do
            unquote_splicing(args) ->
              raise "Unmocked function #{unquote(fun_name)}/#{unquote(arity)}"
          end}}
      end)
      |> Keyword.drop(unquote(@passthrough_functions))

    quote do
      {
        aec_db_mock,
        mock_blocks,
        mock_transactions,
        mock_accounts
      } = unquote(__MODULE__).generate_blockchain(unquote(initial_balances), unquote(blocks))

      aec_db_mock = Keyword.merge(unquote(aec_db), aec_db_mock)

      Mock.with_mocks [{:aec_db, [:passthrough], aec_db_mock}] do
        var!(blocks) = mock_blocks
        var!(transactions) = mock_transactions
        var!(accounts) = mock_accounts

        # HACK: To remove unused warnings
        {var!(blocks), var!(transactions), var!(accounts)}

        unquote(body)
      end
    end
  end

  defmacrop is_transaction(mocked_tx) do
    quote do
      elem(unquote(mocked_tx), 0) in [:spend_tx]
    end
  end

  @spec spend_tx(account_id(), account_id(), non_neg_integer()) :: :aetx.t()
  def spend_tx(sender_id, recipient_id, amount) do
    {:spend_tx, sender_id, recipient_id, amount}
  end

  @spec generate_blockchain(Keyword.t(), Keyword.t()) :: {Keyword.t(), map(), map(), map()}
  def generate_blockchain(initial_balances, blocks) do
    mock_accounts =
      Enum.into(initial_balances, %{}, fn {account_name, _balance} ->
        %{public: account_pkey} = :enacl.sign_keypair()

        {account_name, :aeser_id.create(:account, account_pkey)}
      end)

    {mock_blocks, mock_transactions, _max_height} =
      blocks
      |> Enum.reduce({%{}, %{}, 1}, fn
        {kb_name, []}, {mock_blocks, mock_transactions, height} ->
          {
            Map.put(mock_blocks, kb_name, mock_key_block(height)),
            mock_transactions,
            height + 1
          }

        {kb_name, [{_mb1, [{_name, tx1} | _txs]} | _mbs] = microblocks},
        {mock_blocks, mock_txs, height}
        when is_transaction(tx1) ->
          {_prev_hash, new_mock_blocks, new_mock_txs} =
            create_generation(kb_name, height, microblocks, mock_accounts)

          {
            Map.merge(mock_blocks, new_mock_blocks),
            Map.merge(mock_txs, new_mock_txs),
            height + 1
          }

        {mb_name, [{_name, tx1} | _txs] = transactions}, {mock_blocks, mock_txs, height}
        when is_transaction(tx1) ->
          {_prev_hash, new_mock_blocks, new_mock_txs} =
            create_generation(height, height, [{mb_name, transactions}], mock_accounts)

          {
            Map.merge(mock_blocks, new_mock_blocks),
            Map.merge(mock_txs, new_mock_txs),
            height + 1
          }
      end)

    aec_db_mock = [
      find_block: fn hash ->
        find_block(hash, mock_blocks)
      end,
      get_block: fn hash ->
        {:value, block} = find_block(hash, mock_blocks)

        block
      end,
      get_header: fn hash ->
        {:value, block} = find_block(hash, mock_blocks)

        :aec_blocks.to_header(block)
      end
    ]

    blocks_pkeys =
      Enum.into(mock_blocks, %{}, fn {block_name, block} ->
        header = :aec_blocks.to_header(block)
        {:ok, block_hash} = :aec_headers.hash_header(header)

        hash_type =
          case :aec_blocks.type(block) do
            :key -> :key_block_hash
            :micro -> :micro_block_hash
          end

        block_info =
          put_micro_block_txs(
            %{
              hash: :aeser_api_encoder.encode(hash_type, block_hash),
              height: :aec_blocks.height(block),
              time: :aec_blocks.time_in_msecs(block),
              block: block
            },
            hash_type,
            block
          )

        {block_name, block_info}
      end)

    {aec_db_mock, blocks_pkeys, mock_transactions, mock_accounts}
  end

  defp create_generation(kb_name, height, microblocks, mock_accounts) do
    key_block = mock_key_block(height)

    {:ok, kb_hash} =
      key_block
      |> :aec_blocks.to_key_header()
      |> :aec_headers.hash_header()

    initial_mock_blocks = %{kb_name => key_block}

    {_prev_hash, _new_mock_blocks, _new_mock_txs} =
      Enum.reduce(microblocks, {kb_hash, initial_mock_blocks, %{}}, fn {mb_name, transactions},
                                                                       {prev_hash, mock_blocks,
                                                                        mock_txs} ->
        {micro_block, new_mock_txs} =
          mock_micro_block(transactions, mock_accounts, height, prev_hash, kb_hash)

        {:ok, mb_hash} =
          micro_block
          |> :aec_blocks.to_micro_header()
          |> :aec_headers.hash_header()

        {
          mb_hash,
          Map.put(mock_blocks, mb_name, micro_block),
          Map.merge(mock_txs, new_mock_txs)
        }
      end)
  end

  defp put_micro_block_txs(block_info, :micro_block_hash, block) do
    Map.put(block_info, :txs, :aec_blocks.txs(block))
  end

  defp put_micro_block_txs(block_info, _other_hash, _block), do: block_info

  defp mock_key_block(height, prev_hash \\ nil) do
    miner_pk = :crypto.strong_rand_bytes(32)
    prev_hash = prev_hash || :crypto.strong_rand_bytes(32)

    :aec_blocks.new_key(height, prev_hash, <<>>, <<>>, 0, 0, 0, :default, 0, miner_pk, miner_pk)
  end

  defp mock_micro_block(transactions, accounts, height, prev_hash, kb_hash) do
    mock_txs =
      Enum.into(transactions, %{}, fn {tx_name, tx} ->
        {:ok, aetx} = serialize_tx(tx, accounts)
        signed_tx = :aetx_sign.new(aetx, [])
        {tx_name, signed_tx}
      end)

    {:aec_blocks.new_micro(
       height,
       prev_hash,
       kb_hash,
       <<>>,
       <<>>,
       Map.values(mock_txs),
       System.system_time(),
       :no_fraud,
       0
     ), mock_txs}
  end

  defp find_block(hash, blocks) do
    blocks
    |> Enum.find(fn {_block_name, block} ->
      header = :aec_blocks.to_header(block)
      {:ok, block_hash} = :aec_headers.hash_header(header)

      block_hash == hash
    end)
    |> case do
      nil -> :none
      {_block_name, block} -> {:value, block}
    end
  end

  defp serialize_tx({:spend_tx, sender_id, recipient_id, amount}, accounts) do
    :aec_spend_tx.new(%{
      sender_id: Map.fetch!(accounts, sender_id),
      recipient_id: Map.fetch!(accounts, recipient_id),
      amount: amount,
      fee: 0,
      nonce: 0,
      payload: <<>>
    })
  end
end
