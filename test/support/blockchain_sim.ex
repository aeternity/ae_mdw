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

  @spec spend_tx(account_id(), account_id(), non_neg_integer()) :: :aetx.t()
  def spend_tx(sender_id, recipient_id, amount) do
    {:spend_tx, sender_id, recipient_id, amount}
  end

  def generate_blockchain(initial_balances, blocks) do
    mock_accounts =
      Enum.into(initial_balances, %{}, fn {account_id, _balance} ->
        %{public: account_pkey} = :enacl.sign_keypair()

        {account_id, :aeser_id.create(:account, account_pkey)}
      end)

    {mock_blocks, mock_transactions, _max_height} =
      blocks
      |> Enum.reduce({%{}, %{}, 1}, fn
        {block_id, {:kb, account_id}}, {mock_blocks, mock_transactions, height}
        when is_atom(account_id) ->
          {
            Map.put(mock_blocks, block_id, mock_key_block(account_id, mock_accounts, height)),
            mock_transactions,
            height + 1
          }

        {block_id, transactions}, {mock_blocks, mock_transactions, height}
        when is_list(transactions) ->
          {micro_block, transactions} = mock_micro_block(transactions, mock_accounts, height)

          {
            Map.put(mock_blocks, block_id, micro_block),
            Map.merge(mock_transactions, transactions),
            height
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
      Enum.into(mock_blocks, %{}, fn {block_id, block} ->
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

        {block_id, block_info}
      end)

    {aec_db_mock, blocks_pkeys, mock_transactions, mock_accounts}
  end

  defp put_micro_block_txs(block_info, :micro_block_hash, block) do
    txs = block |> :aec_blocks.txs() |> Enum.map(fn {:ok, tx} -> tx end)
    Map.put(block_info, :txs, txs)
  end

  defp put_micro_block_txs(block_info, _other_hash, _block), do: block_info

  defp mock_key_block(account_id, accounts, height) do
    miner_pk = accounts |> Map.fetch!(account_id) |> :aeser_id.specialize(:account)

    :aec_blocks.new_key(height, <<>>, <<>>, <<>>, 0, 0, 0, :default, 0, miner_pk, miner_pk)
  end

  defp mock_micro_block(transactions, accounts, height) do
    txs = Enum.into(transactions, %{}, fn {tx_id, tx} -> {tx_id, serialize_tx(tx, accounts)} end)

    {:aec_blocks.new_micro(height, <<>>, <<>>, <<>>, <<>>, Map.values(txs), 0, :no_fraud, 0), txs}
  end

  defp find_block(hash, blocks) do
    blocks
    |> Enum.find(fn {_block_id, block} ->
      header = :aec_blocks.to_header(block)
      {:ok, block_hash} = :aec_headers.hash_header(header)

      block_hash == hash
    end)
    |> case do
      nil -> :none
      {_block_id, block} -> {:value, block}
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
