defmodule AeMdwWeb.AexnLogViewTest do
  use ExUnit.Case

  alias AeMdw.Contracts
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdwWeb.AexnLogView
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Db.State

  import AeMdw.Util.Encoding
  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 5]

  require Model

  @height 1
  @mbi 100
  @mb_hash :crypto.strong_rand_bytes(32)
  @limit 101

  setup_all _context do
    account1_pk = :crypto.strong_rand_bytes(32)
    account2_pk = :crypto.strong_rand_bytes(32)

    tokens = %{
      "Burn" => Enum.random(100..999),
      "Mint" => Enum.random(100..999),
      "Swap" => Enum.random(100..999),
      "Transfer" => Enum.random(100..999),
      "TemplateMint" => Enum.random(100..999)
    }

    aex9_event_args = %{
      burn: [account1_pk, <<tokens["Burn"]::256>>],
      mint: [account1_pk, <<tokens["Mint"]::256>>],
      swap: [account1_pk, <<tokens["Swap"]::256>>],
      transfer: [account1_pk, account2_pk, <<tokens["Transfer"]::256>>]
    }

    {aex9_logs, store} =
      NullStore.new()
      |> MemStore.new()
      |> logs_setup(aex9_event_args)

    templates = %{
      "TemplateCreation" => Enum.random(100..999),
      "TemplateDeletion" => Enum.random(100..999),
      "TemplateMint" => Enum.random(100..999),
      "TemplateLimitDecrease" => Enum.random(100..999),
      "EditionLimit" => Enum.random(100..999)
    }

    aex141_event_args = %{
      burn: [account1_pk, <<tokens["Burn"]::256>>],
      mint: [account1_pk, <<tokens["Mint"]::256>>],
      transfer: [account1_pk, account2_pk, <<tokens["Transfer"]::256>>],
      template_creation: [<<templates["TemplateCreation"]::256>>],
      template_deletion: [<<templates["TemplateDeletion"]::256>>],
      template_mint: [
        account1_pk,
        <<templates["TemplateMint"]::256>>,
        <<tokens["TemplateMint"]::256>>
      ],
      template_limit_decrease: [<<templates["TemplateLimitDecrease"]::256>>, <<@limit::256>>],
      edition_limit: [<<templates["EditionLimit"]::256>>, <<@limit::256>>]
    }

    {aex141_logs, store} = logs_setup(store, aex141_event_args)

    [
      store: store,
      aex9_logs: aex9_logs,
      aex141_logs: aex141_logs,
      account1_pk: account1_pk,
      account2_pk: account2_pk,
      tokens: tokens,
      templates: templates
    ]
  end

  describe "render_log/3" do
    test "formats logs from aex9 events", %{
      aex9_logs: logs,
      account1_pk: account1_pk,
      account2_pk: account2_pk,
      tokens: tokens,
      store: store
    } do
      state = State.new(store)

      Enum.each(logs, fn {create_txi, txi, evt_hash, log_idx} = contract_log_index ->
        %{
          contract_txi: ^create_txi,
          contract_tx_hash: contract_tx_hash,
          contract_id: contract_id,
          call_txi: ^txi,
          call_tx_hash: call_tx_hash,
          args: args,
          data: data,
          event_hash: event_hash,
          event_name: event_name,
          height: height,
          micro_index: mbi,
          block_hash: mb_hash,
          log_idx: ^log_idx
        } =
          store
          |> State.new()
          |> AexnLogView.render_log(contract_log_index, true)

        assert contract_id == encode_contract(Origin.pubkey(state, {:contract, create_txi}))
        assert contract_tx_hash == encode_to_hash(state, create_txi)
        assert call_tx_hash == encode_to_hash(state, txi)
        assert_args(event_name, account1_pk, account2_pk, tokens, args)
        assert data == "0x" <> Integer.to_string(txi, 16)
        assert Base.hex_decode32!(event_hash) == evt_hash
        event_type = String.to_existing_atom(Macro.underscore(event_name))
        assert evt_hash == aexn_event_hash(event_type)
        assert height == @height
        assert mbi == @mbi
        assert mb_hash == encode(:micro_block_hash, @mb_hash)
      end)
    end

    test "formats logs from aex141 events", %{
      aex141_logs: logs,
      account1_pk: account1_pk,
      account2_pk: account2_pk,
      templates: templates,
      tokens: tokens,
      store: store
    } do
      state = State.new(store)

      Enum.each(logs, fn {create_txi, txi, evt_hash, log_idx} = contract_log_index ->
        %{
          contract_txi: ^create_txi,
          contract_tx_hash: contract_tx_hash,
          contract_id: contract_id,
          call_txi: ^txi,
          call_tx_hash: call_tx_hash,
          args: args,
          data: data,
          event_hash: event_hash,
          event_name: event_name,
          height: height,
          micro_index: mbi,
          block_hash: mb_hash,
          log_idx: ^log_idx
        } =
          store
          |> State.new()
          |> AexnLogView.render_log(contract_log_index, true)

        assert contract_id == encode_contract(Origin.pubkey(state, {:contract, create_txi}))
        assert contract_tx_hash == encode_to_hash(state, create_txi)
        assert call_tx_hash == encode_to_hash(state, txi)
        assert_args(event_name, account1_pk, account2_pk, tokens, args)
        assert_template_args(event_name, account1_pk, templates, tokens, args)
        assert data == "0x" <> Integer.to_string(txi, 16)
        assert Base.hex_decode32!(event_hash) == evt_hash
        event_type = String.to_existing_atom(Macro.underscore(event_name))
        assert evt_hash == aexn_event_hash(event_type)
        assert height == @height
        assert mbi == @mbi
        assert mb_hash == encode(:micro_block_hash, @mb_hash)
      end)
    end

    test "renders logs with remote calls" do
      {height, mbi} = block_index = {100_000, 12}
      contract_pk = :crypto.strong_rand_bytes(32)
      remote_pk = :crypto.strong_rand_bytes(32)
      evt_hash0 = aexn_event_hash(:transfer)
      evt_hash1 = <<123::256>>
      extra_logs = [{remote_pk, [evt_hash1, <<3::256>>, <<4::256>>, <<1234::256>>], <<>>}]
      call_rec = call_rec("transfer", contract_pk, height, contract_pk, extra_logs)

      call_txi = height * 1_000
      remote_txi = call_txi - 2
      create_txi = call_txi - 1
      block_hash = <<100_012::256>>

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: remote_txi, id: <<remote_txi::256>>, block_index: block_index)
        )
        |> State.put(
          Model.Tx,
          Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index)
        )
        |> State.put(Model.Block, Model.block(index: block_index, hash: block_hash))
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
        )
        |> State.put(
          Model.RevOrigin,
          Model.rev_origin(index: {remote_txi, :contract_create_tx, remote_pk})
        )
        |> State.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> State.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, remote_pk, remote_txi})
        )
        |> Contract.logs_write(create_txi, call_txi, call_rec)

      assert {:ok, _prev, [log1, log2], _next} =
               Contracts.fetch_logs(state, {:forward, false, 100, false}, nil, %{}, nil)

      contract_id = encode_contract(contract_pk)
      contract_tx_hash = encode_to_hash(state, create_txi)
      remote_id = encode_contract(remote_pk)
      remote_tx_hash = encode_to_hash(state, remote_txi)

      call_tx_hash = encode_to_hash(state, call_txi)
      mb_hash = encode(:micro_block_hash, block_hash)

      event_hash0 = Base.hex_encode32(evt_hash0)
      event_hash1 = Base.hex_encode32(evt_hash1)

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash0,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 0,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: nil
             } = AexnLogView.render_log(state, log1, false)

      assert %{
               contract_id: ^contract_id,
               contract_tx_hash: ^contract_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash1,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 1,
               ext_caller_contract_txi: ^remote_txi,
               ext_caller_contract_tx_hash: ^remote_tx_hash,
               ext_caller_contract_id: ^remote_id,
               parent_contract_id: nil
             } = AexnLogView.render_log(state, log2, false)

      assert {:ok, _prev, [log3], _next} =
               Contracts.fetch_logs(
                 state,
                 {:forward, false, 100, false},
                 nil,
                 %{"contract" => remote_id},
                 nil
               )

      assert %{
               contract_id: ^remote_id,
               contract_tx_hash: ^remote_tx_hash,
               call_txi: ^call_txi,
               call_tx_hash: ^call_tx_hash,
               event_hash: ^event_hash1,
               height: ^height,
               micro_index: ^mbi,
               block_hash: ^mb_hash,
               log_idx: 1,
               ext_caller_contract_txi: -1,
               ext_caller_contract_tx_hash: nil,
               ext_caller_contract_id: nil,
               parent_contract_id: ^contract_id
             } = AexnLogView.render_log(state, log3, false)
    end
  end

  defp assert_args(event_name, account1_pk, _account2_pk, tokens, [account, token_id])
       when event_name in ["Burn", "Mint", "Swap"] do
    assert account == encode_account(account1_pk)
    assert token_id == tokens[event_name]
  end

  defp assert_args("Transfer", account1_pk, account2_pk, tokens, [from, to, token_id]) do
    assert from == encode_account(account1_pk)
    assert to == encode_account(account2_pk)
    assert token_id == tokens["Transfer"]
  end

  defp assert_args(_event_name, _account1_pk, _account2_pk, _tokens, _args), do: :ok

  defp assert_template_args("TemplateCreation" = event, _account1_pk, templates, _tokens, [
         template_id
       ]) do
    assert template_id == to_string(templates[event])
  end

  defp assert_template_args("TemplateDeletion" = event, _account1_pk, templates, _tokens, [
         template_id
       ]) do
    assert template_id == to_string(templates[event])
  end

  defp assert_template_args("TemplateMint" = event, account1_pk, templates, tokens, [
         account,
         template_id,
         token_id
       ]) do
    assert account == encode_account(account1_pk)
    assert template_id == templates[event]
    assert token_id == tokens[event]
  end

  defp assert_template_args("TemplateLimitDecrease" = event, _account1_pk, templates, _tokens, [
         template_id,
         limit
       ]) do
    assert template_id == to_string(templates[event])
    assert limit == to_string(@limit)
  end

  defp assert_template_args("EditionLimit" = event, _account1_pk, templates, _tokens, [
         template_id,
         limit
       ]) do
    assert template_id == to_string(templates[event])
    assert limit == to_string(@limit)
  end

  defp assert_template_args(_event, _account1_pk, _templates, _tokens, _args), do: :ok

  defp logs_setup(store, event_args) do
    block_index = {@height, @mbi}
    contract_pk = :crypto.strong_rand_bytes(32)
    create_txi = Enum.random(1_000..9_999)

    store =
      store
      |> Store.put(
        Model.Block,
        Model.block(index: block_index, hash: @mb_hash)
      )
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
      )
      |> Store.put(
        Model.Tx,
        Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index)
      )

    event_args
    |> Enum.with_index(create_txi + 1)
    |> Enum.map_reduce(store, fn {{event, args}, txi}, store ->
      evt_hash = aexn_event_hash(event)
      data = "0x" <> Integer.to_string(txi, 16)
      idx = rem(txi, 10)
      contract_log_index = {create_txi, txi, evt_hash, idx}

      m_log =
        Model.contract_log(
          index: contract_log_index,
          args: args,
          data: data
        )

      m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, idx})
      m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, idx})
      m_idx_log = Model.idx_contract_log(index: {txi, idx, create_txi, evt_hash})

      store =
        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index))
        |> Store.put(Model.ContractLog, m_log)
        |> Store.put(Model.DataContractLog, m_data_log)
        |> Store.put(Model.EvtContractLog, m_evt_log)
        |> Store.put(Model.IdxContractLog, m_idx_log)

      {contract_log_index, store}
    end)
  end
end
