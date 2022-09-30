defmodule AeMdwWeb.BlockchainSim do
  @moduledoc """
  Creates local generations allowing declarative test case setup by naming blocks and accounts.
  """

  alias AeMdw.Validate

  require Mock

  @genesis_prev_hash AeMdw.Util.max_256bit_bin()
  @initial_height 0
  @initial_target 553_713_663
  @passthrough_functions ~w(module_info)a

  @type account_name() :: atom()

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

      Mock.with_mocks [
        {:aec_db, [:passthrough], aec_db_mock},
        {:aec_chain, [],
         get_header: fn :mb_hash ->
           mblock0 = mock_blocks[:mb][:block]
           {:ok, :aec_blocks.to_header(mblock0)}
         end}
      ] do
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
      elem(unquote(mocked_tx), 0) in [:spend_tx, :oracle_register_tx]
    end
  end

  @spec spend_tx(account_name(), account_name(), non_neg_integer()) :: :aetx.t()
  def spend_tx(sender_name, recipient_name, amount) do
    {:spend_tx, sender_name, recipient_name, amount}
  end

  @spec oracle_register_tx(account_name(), map()) :: :aetx.t()
  def oracle_register_tx(account_name, args \\ %{}) when is_map(args) do
    {:oracle_register_tx, account_name, args}
  end

  @spec generate_blockchain(Keyword.t(), Keyword.t()) :: {Keyword.t(), map(), map(), map()}
  def generate_blockchain(initial_balances, blocks) do
    mock_accounts =
      Enum.into(initial_balances, %{}, fn {account_name, _balance} ->
        %{public: account_pkey} = :enacl.sign_keypair()

        {account_name, :aeser_id.create(:account, account_pkey)}
      end)

    {_prev_hash, mock_blocks, mock_txs, _max_height} =
      blocks
      |> Enum.reduce({@genesis_prev_hash, %{}, %{}, @initial_height}, fn
        {mb_name, [{_name, tx1} | _txs] = named_txs}, {prev_hash, mock_blocks, mock_txs, height}
        when is_transaction(tx1) ->
          {last_hash, new_mock_blocks, new_mock_txs} =
            create_generation(prev_hash, height, height, [{mb_name, named_txs}], mock_accounts)

          {
            last_hash,
            Map.merge(mock_blocks, new_mock_blocks),
            Map.merge(mock_txs, new_mock_txs),
            height + 1
          }

        {kb_name, named_mbs}, {prev_hash, mock_blocks, mock_txs, height} ->
          {last_hash, new_mock_blocks, new_mock_txs} =
            create_generation(prev_hash, kb_name, height, named_mbs, mock_accounts)

          {
            last_hash,
            Map.merge(mock_blocks, new_mock_blocks),
            Map.merge(mock_txs, new_mock_txs),
            height + 1
          }
      end)

    aec_db_mock = [
      find_block: fn hash ->
        find_block(hash, mock_blocks)
      end,
      find_tx_location: fn _tx_hash -> :mb_hash end,
      find_tx_with_location: fn _tx_hash ->
        mblock0 = mock_blocks[:mb]
        header = :aec_blocks.to_header(mblock0)
        {:ok, block_hash} = :aec_headers.hash_header(header)

        {block_hash, hd(:aec_blocks.txs(mblock0))}
      end,
      get_block: fn hash ->
        {:value, block} = find_block(hash, mock_blocks)

        block
      end,
      get_header: fn hash ->
        {:value, block} = find_block(hash, mock_blocks)

        :aec_blocks.to_header(block)
      end,
      get_genesis_hash: fn ->
        Validate.id!("kh_wUCideEB8aDtUaiHCtKcfywU6oHZW6gnyci8Mw6S1RSTCnCRu")
      end
    ]

    named_blocks_txs =
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

    {aec_db_mock, named_blocks_txs, mock_txs, mock_accounts}
  end

  defp create_generation(prev_hash, kb_name, height, microblocks, mock_accounts) do
    key_block = mock_key_block(height, prev_hash)

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

  defp mock_key_block(0, prev_hash) do
    initializer_pk = Validate.id!("ak_11111111111111111111111111111111273Yts")

    :aec_blocks.new_key(
      0,
      prev_hash,
      prev_hash,
      Validate.id!("bs_2aBz1QS23piMnSmZGwQk8iNCHLBdHSycPBbA5SHuScuYfHATit"),
      @initial_target,
      0,
      0,
      :default,
      1,
      initializer_pk,
      initializer_pk
    )
  end

  defp mock_key_block(height, prev_hash) do
    default_target = :aec_consensus_bitcoin_ng.default_target()
    time = System.system_time(:millisecond)
    protocol = :aec_hard_forks.protocol_effective_at_height(height)
    miner_pk = :crypto.strong_rand_bytes(32)
    benefeciary_pk = :crypto.strong_rand_bytes(32)

    :aec_blocks.new_key(
      height,
      prev_hash,
      prev_hash,
      <<>>,
      default_target,
      0,
      time,
      :default,
      protocol,
      miner_pk,
      benefeciary_pk
    )
  end

  defp mock_micro_block(transactions, accounts, height, prev_hash, kb_hash) do
    mock_txs =
      Enum.into(transactions, %{}, fn {tx_name, tx} when is_transaction(tx) ->
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

  defp serialize_tx({:spend_tx, sender_name, recipient_name, amount}, accounts) do
    :aec_spend_tx.new(%{
      sender_id: Map.fetch!(accounts, sender_name),
      recipient_id: Map.fetch!(accounts, recipient_name),
      amount: amount,
      fee: 0,
      nonce: 1,
      payload: <<>>
    })
  end

  defp serialize_tx({:oracle_register_tx, register_name, args}, accounts) do
    %{
      account_id: Map.fetch!(accounts, register_name),
      nonce: 1,
      query_format: "foo",
      abi_version: 1,
      response_format: "bar",
      query_fee: 10,
      oracle_ttl: {:delta, 1_000},
      fee: 10_000
    }
    |> Map.merge(args)
    |> :aeo_register_tx.new()
  end
end
