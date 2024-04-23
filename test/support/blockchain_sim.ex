defmodule AeMdwWeb.BlockchainSim do
  @moduledoc """
  Creates local generations allowing declarative test case setup by naming blocks and accounts.
  """

  alias AeMdw.Validate

  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 2]

  require Mock

  @genesis_prev_hash AeMdw.Util.max_256bit_bin()
  @initial_height 0
  @initial_target 553_713_663
  @passthrough_functions ~w(module_info)a

  @type account_name() :: atom()
  @type tx_type() :: AeMdw.Node.tx_type()

  defmacro with_blockchain(initial_balances, blocks, extra_mocks \\ [], do: body) do
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

      ga_mocks =
        case mock_accounts[:ga] do
          {:id, :account, ga_pk} ->
            %{hash: block_hash} = mock_blocks[:mb]
            block_hash = Validate.id!(block_hash)
            ga_tx = Keyword.get(mock_transactions, :ga_tx)
            ga_tx_hash = if ga_tx, do: :aetx_sign.hash(ga_tx)

            if ga_tx_hash do
              [
                {:aec_chain, [:passthrough],
                 get_ga_call: fn ^ga_pk, _auth_id, _block_hash ->
                   {:ok, :aega_call.new({:id, :account, ga_pk}, ga_pk, 1, 10_000, 2_000, :ok, "")}
                 end,
                 get_contract_call: fn _ga_pk, _call_id, ^block_hash ->
                   {:ok, call_rec("attach", ga_pk)}
                 end}
              ]
            else
              []
            end

          nil ->
            [
              {:aec_chain, [:passthrough], genesis_block: fn -> mock_blocks[0][:block] end}
            ]
        end

      pf_mocks =
        case mock_accounts[:pf] do
          {:id, :account, pf_pk} ->
            %{hash: block_hash} = mock_blocks[:mb]
            block_hash = Validate.id!(block_hash)
            pf_tx = Keyword.get(mock_transactions, :pf_tx)
            pf_tx_hash = if pf_tx, do: :aetx_sign.hash(pf_tx)

            if pf_tx_hash do
              [
                {:aec_chain, [:passthrough],
                 get_contract_call: fn _pk, _call_id, ^block_hash ->
                   {:ok, call_rec("paying_for", pf_pk)}
                 end}
              ]
            else
              []
            end

          nil ->
            []
        end

      Mock.with_mocks [{:aec_db, [:passthrough], aec_db_mock}] ++
                        ga_mocks ++ pf_mocks ++ unquote(extra_mocks) do
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
      elem(unquote(mocked_tx), 0) in [
        :spend_tx,
        :oracle_register_tx,
        :oracle_query_tx,
        :name_claim_tx,
        :name_update_tx,
        :name_revoke_tx,
        :ga_attach_tx,
        :ga_meta_tx,
        :paying_for_tx,
        :contract_create_tx,
        :contract_call_tx
      ]
    end
  end

  @spec spend_tx(account_name(), account_name(), non_neg_integer()) :: tuple()
  def spend_tx(sender_name, recipient, amount) do
    {:spend_tx, sender_name, recipient, amount}
  end

  @spec tx(tx_type(), account_name(), map()) :: tuple()
  def tx(tx_type, account_name, args \\ %{}) when is_map(args) do
    {tx_type, account_name, args}
  end

  @spec name_tx(tx_type(), account_name(), binary(), map()) :: tuple()
  def name_tx(type, account_name, plain_name, args \\ %{}) when is_map(args) do
    {type, account_name, plain_name, args}
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
      |> Enum.reduce({@genesis_prev_hash, %{}, [], @initial_height}, fn
        {mb_name, [{_name, tx1} | _txs] = named_txs}, {prev_hash, mock_blocks, mock_txs, height}
        when is_transaction(tx1) ->
          {last_hash, new_mock_blocks, new_mock_txs} =
            create_generation(prev_hash, height, height, [{mb_name, named_txs}], mock_accounts)

          {
            last_hash,
            Map.merge(mock_blocks, new_mock_blocks),
            Kernel.++(mock_txs, new_mock_txs),
            height + 1
          }

        {kb_name, named_mbs}, {prev_hash, mock_blocks, mock_txs, height} ->
          {last_hash, new_mock_blocks, new_mock_txs} =
            create_generation(prev_hash, kb_name, height, named_mbs, mock_accounts)

          {
            last_hash,
            Map.merge(mock_blocks, new_mock_blocks),
            Kernel.++(mock_txs, new_mock_txs),
            height + 1
          }
      end)

    aec_db_mock = [
      find_block: fn hash ->
        find_block(hash, mock_blocks)
      end,
      find_header: fn hash ->
        {:value, block} = find_block(hash, mock_blocks)
        {:value, :aec_blocks.to_header(block)}
      end,
      find_tx_location: fn _tx_hash ->
        header = mock_blocks[:mb] |> :aec_blocks.to_header()
        {:ok, mb0_hash} = :aec_headers.hash_header(header)
        mb0_hash
      end,
      find_tx_with_location: fn tx_hash ->
        mock_blocks
        |> Map.values()
        |> Enum.filter(&(elem(&1, 0) == :mic_block))
        |> Enum.map(fn mblock ->
          header = :aec_blocks.to_header(mblock)
          {:ok, block_hash} = :aec_headers.hash_header(header)

          {block_hash, :aec_blocks.txs(mblock)}
        end)
        |> Enum.find_value(fn {block_hash, txs} ->
          tx = Enum.find(txs, &(:aetx_sign.hash(&1) == tx_hash))
          if tx, do: {block_hash, tx}
        end)
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
      end,
      get_top_block_hash: fn ->
        top_block = mock_blocks[:top_block]
        header = :aec_blocks.to_header(top_block)
        {:ok, block_hash} = :aec_headers.hash_header(header)
        block_hash
      end,
      ensure_activity: fn _type, fun ->
        fun.()
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

    initial_mock_blocks = %{kb_name => key_block, :top_block => key_block}

    {_prev_hash, _new_mock_blocks, _new_mock_txs} =
      Enum.reduce(microblocks, {kb_hash, initial_mock_blocks, []}, fn {mb_name, transactions},
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
          Map.merge(mock_blocks, %{mb_name => micro_block, :top_block => key_block}),
          Kernel.++(mock_txs, new_mock_txs)
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
      Enum.into(transactions, [], fn {tx_name, tx} when is_transaction(tx) ->
        {:ok, aetx} = create_aetx(tx, accounts)
        signed_tx = :aetx_sign.new(aetx, [])
        {tx_name, signed_tx}
      end)

    {:aec_blocks.new_micro(
       height,
       prev_hash,
       kb_hash,
       <<>>,
       <<>>,
       Keyword.values(mock_txs),
       :aeu_time.now_in_msecs(),
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

  defp create_aetx({:spend_tx, sender_name, recipient, amount}, accounts) do
    recipient_id =
      case recipient do
        {:id, :name, _hash} = id -> id
        recipient_name -> Map.fetch!(accounts, recipient_name)
      end

    :aec_spend_tx.new(%{
      sender_id: Map.fetch!(accounts, sender_name),
      recipient_id: recipient_id,
      amount: amount,
      fee: 0,
      nonce: 1,
      payload: <<>>
    })
  end

  defp create_aetx({:oracle_query_tx, sender_name, oracle_id, args}, accounts) do
    %{
      sender_id: Map.fetch!(accounts, sender_name),
      nonce: 1,
      oracle_id: oracle_id,
      query: "",
      query_fee: 10_000,
      query_ttl: {:delta, 2},
      response_ttl: {:delta, 3},
      fee: 20_000
    }
    |> Map.merge(args)
    |> :aeo_query_tx.new()
  end

  defp create_aetx({:oracle_register_tx, register_name, args}, accounts) do
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

  defp create_aetx({:name_claim_tx, account_name, plain_name, args}, accounts) do
    %{
      account_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      name: plain_name,
      name_salt: 123_456,
      fee: 5_000
    }
    |> Map.merge(args)
    |> :aens_claim_tx.new()
  end

  defp create_aetx({:name_update_tx, account_name, plain_name, args}, accounts) do
    {:id, :account, pubkey} = account_id = Map.fetch!(accounts, account_name)
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    pointers =
      case args[:pointers] do
        nil ->
          [
            {:pointer, "account_pubkey", account_id},
            {:pointer, "oracle_pubkey", :aeser_id.create(:oracle, pubkey)}
          ]

        list ->
          Enum.map(list, fn
            {:pointer, key, account_atom} when is_atom(account_atom) ->
              {:pointer, key, Map.fetch!(accounts, account_atom)}

            another_pointer ->
              another_pointer
          end)
      end

    args = Map.delete(args, :pointers)

    %{
      account_id: account_id,
      nonce: 1,
      name_id: :aeser_id.create(:name, name_hash),
      name_ttl: 1_000,
      pointers: pointers,
      client_ttl: 1_000,
      fee: 5_000
    }
    |> Map.merge(args)
    |> :aens_update_tx.new()
  end

  defp create_aetx({:name_revoke_tx, account_name, plain_name, args}, accounts) do
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    %{
      account_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      name_id: :aeser_id.create(:name, name_hash),
      fee: 5_000
    }
    |> Map.merge(args)
    |> :aens_revoke_tx.new()
  end

  defp create_aetx({:ga_attach_tx, account_name, args}, accounts) do
    %{
      owner_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      code: :erlang.list_to_binary([?o, ?k]),
      auth_fun: <<1::256>>,
      vm_version: 7,
      abi_version: 3,
      gas: 25_000,
      gas_price: 1_000_000_000,
      call_data: :erlang.list_to_binary([?o, ?k]),
      fee: 100
    }
    |> Map.merge(args)
    |> :aega_attach_tx.new()
  end

  defp create_aetx({:ga_meta_tx, account_name, args}, accounts) do
    {:ok, inner_tx} =
      %{
        sender_id: Map.fetch!(accounts, account_name),
        recipient_id: :aeser_id.create(:account, <<2::256>>),
        amount: 123,
        fee: 456,
        nonce: 1,
        payload: <<>>
      }
      |> Map.merge(args)
      |> :aec_spend_tx.new()

    %{
      ga_id: Map.fetch!(accounts, account_name),
      auth_data: <<1::256>>,
      abi_version: 1,
      gas: 20_000,
      gas_price: 1_000,
      fee: 100,
      tx: :aetx_sign.new(inner_tx, [])
    }
    |> Map.merge(args)
    |> :aega_meta_tx.new()
  end

  defp create_aetx({:paying_for_tx, account_name, args}, accounts) do
    {:ok, inner_tx} =
      %{
        sender_id: Map.fetch!(accounts, account_name),
        recipient_id: :aeser_id.create(:account, <<2::256>>),
        amount: 123,
        fee: 456,
        nonce: 1,
        payload: <<>>
      }
      |> Map.merge(args)
      |> :aec_spend_tx.new()

    %{
      payer_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      fee: 100,
      tx: :aetx_sign.new(inner_tx, [])
    }
    |> Map.merge(args)
    |> :aec_paying_for_tx.new()
  end

  defp create_aetx({:contract_create_tx, account_name, args}, accounts) do
    %{
      owner_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      code: :erlang.list_to_binary([?o, ?k]),
      vm_version: 7,
      abi_version: 3,
      deposit: 1_000,
      amount: 123,
      gas: 25_000,
      gas_price: 1_000_000_000,
      call_data: :erlang.list_to_binary([?o, ?k]),
      fee: 100
    }
    |> Map.merge(args)
    |> :aect_create_tx.new()
  end

  defp create_aetx({:contract_call_tx, account_name, args}, accounts) do
    %{
      caller_id: Map.fetch!(accounts, account_name),
      nonce: 1,
      contract_id: <<2::256>>,
      abi_version: 3,
      fee: 100,
      amount: 123,
      gas: 25_000,
      gas_price: 1_000_000_000,
      call_data: :erlang.list_to_binary([?o, ?k])
    }
    |> Map.merge(args)
    |> :aect_call_tx.new()
  end
end
