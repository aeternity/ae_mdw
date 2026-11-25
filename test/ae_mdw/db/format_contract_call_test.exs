defmodule AeMdw.Db.FormatContractCallTest do
  use ExUnit.Case, async: false

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Format
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.DryRun.Contract, as: DryRunContract
  alias AeMdw.EtsCache

  import Mock

  require Model

  @create_txi 100
  @call_txi 200
  @height 300
  @time 1_700_000_000_000

  setup do
    [caller_pk, contract_pk, remote_pk] = for _i <- 1..3, do: :crypto.strong_rand_bytes(32)

    # not aex9
    for pk <- [contract_pk, remote_pk], do: EtsCache.put(Contract, pk, {{}, "6.1.0", <<0::256>>})

    signed_tx =
      caller_pk
      |> DryRunContract.new_call_tx(contract_pk, "get", [])
      |> :aetx_sign.new([])

    mblock =
      :aec_blocks.new_micro(
        @height,
        <<1::256>>,
        <<2::256>>,
        <<>>,
        <<>>,
        [signed_tx],
        @time,
        :no_fraud,
        0
      )

    header = :aec_blocks.to_header(mblock)
    {:ok, mb_hash} = :aec_headers.hash_header(header)

    # the node lists the last log first
    logs = [
      {contract_pk, [<<1::256>>, <<2::256>>], "data"},
      {remote_pk, [<<3::256>>], <<0, 255>>},
      {contract_pk, [<<4::256>>], <<>>}
    ]

    call_rec =
      :aect_call.new(
        :aeser_id.create(:account, caller_pk),
        1,
        :aeser_id.create(:contract, contract_pk),
        @height,
        1_000_000_000
      )

    call_rec = :aect_call.set_log(logs, :aect_call.set_gas_used(1_234, call_rec))

    state =
      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.put(Model.Block, Model.block(index: {@height, 0}, hash: mb_hash))
      |> put_origin(contract_pk, @create_txi)
      |> put_origin(remote_pk, @create_txi + 1)

    {state, m_tx} = put_call(state, @call_txi, signed_tx, contract_pk, call_rec)

    {:ok,
     state: state,
     m_tx: m_tx,
     caller_pk: caller_pk,
     contract_pk: contract_pk,
     call_rec: call_rec,
     block: {mb_hash, header},
     mocks: node_mocks(signed_tx, contract_pk, {mb_hash, header}, call_rec)}
  end

  test "renders the call object fields from mdw rows as from the node", %{
    state: state,
    m_tx: m_tx,
    mocks: mocks
  } do
    with_mocks mocks do
      from_mdw = Format.to_map(state, m_tx)
      raw_from_mdw = Format.to_raw_map(state, m_tx)
      assert_not_called(:aec_chain.get_contract_call(:_, :_, :_))

      state = State.delete(state, Model.ContractCallInfo, @call_txi)

      assert from_mdw == Format.to_map(state, m_tx)
      assert raw_from_mdw == Format.to_raw_map(state, m_tx)
      assert_called(:aec_chain.get_contract_call(:_, :_, :_))

      assert %{"tx" => %{"gas_used" => 1_234, "return_type" => "ok", "log" => [_, _, _]}} =
               from_mdw
    end
  end

  test "reads the node when a log row is missing or lost its address", %{
    state: state,
    contract_pk: contract_pk,
    call_rec: call_rec
  } do
    expected =
      call_rec
      |> :aect_call.serialize_for_client()
      |> Map.take(["gas_used", "return_type", "log"])
      |> Map.update!("log", &Contract.stringfy_log_topics/1)

    assert {:ok, ^expected} = DbContract.call_info(state, contract_pk, @call_txi)

    log_key = {@create_txi, @call_txi, 1}
    {:ok, m_log} = State.get(state, Model.ContractLog, log_key)
    m_remote_log = Model.contract_log(m_log, ext_contract: {:parent_contract_pk, contract_pk})

    assert :not_found ==
             state
             |> State.put(Model.ContractLog, m_remote_log)
             |> DbContract.call_info(contract_pk, @call_txi)

    assert :not_found ==
             state
             |> State.delete(Model.ContractLog, log_key)
             |> DbContract.call_info(contract_pk, @call_txi)
  end

  test "renders a call through a name from mdw rows as from the node", %{
    state: state,
    caller_pk: caller_pk,
    contract_pk: contract_pk,
    call_rec: call_rec,
    block: {mb_hash, _header} = block
  } do
    # maybe_resolve_contract_pk takes pubkeys with this prefix for name hashes
    name_pk = <<217, 52, 92>> <> :crypto.strong_rand_bytes(29)

    {:ok, aetx} =
      :aect_call_tx.new(%{
        caller_id: :aeser_id.create(:account, caller_pk),
        nonce: 2,
        contract_id: :aeser_id.create(:name, name_pk),
        abi_version: 3,
        fee: 100,
        amount: 0,
        gas: 25_000,
        gas_price: 1_000_000_000,
        call_data: ""
      })

    signed_tx = :aetx_sign.new(aetx, [])
    call_txi = @call_txi + 1
    {state, m_tx} = put_call(state, call_txi, signed_tx, contract_pk, call_rec)

    mocks = [
      {Name, [:passthrough],
       [ptr_resolve: fn ^mb_hash, ^name_pk, "contract_pubkey" -> {:ok, contract_pk} end]}
      | node_mocks(signed_tx, name_pk, block, call_rec)
    ]

    with_mocks mocks do
      from_mdw = Format.to_map(state, m_tx)
      raw_from_mdw = Format.to_raw_map(state, m_tx)
      assert_not_called(:aec_chain.get_contract_call(:_, :_, :_))

      state = State.delete(state, Model.ContractCallInfo, call_txi)

      assert from_mdw == Format.to_map(state, m_tx)
      assert raw_from_mdw == Format.to_raw_map(state, m_tx)
      assert_called(:aec_chain.get_contract_call(name_pk, :_, mb_hash))
    end
  end

  defp put_call(state, call_txi, signed_tx, contract_pk, call_rec) do
    m_tx =
      Model.tx(
        index: call_txi,
        id: :aetx_sign.hash(signed_tx),
        block_index: {@height, 0},
        time: @time
      )

    fun_arg_res = %{function: "get", arguments: [], result: %{type: :int, value: 1}}
    mutation = ContractCallMutation.new(contract_pk, call_txi, fun_arg_res, call_rec)

    {Mutation.execute(mutation, State.put(state, Model.Tx, m_tx)), m_tx}
  end

  defp node_mocks(signed_tx, contract_or_name_pk, {mb_hash, header}, call_rec) do
    tx_hash = :aetx_sign.hash(signed_tx)

    [
      {:aec_db, [:passthrough],
       [
         find_tx_with_location: fn ^tx_hash -> {mb_hash, signed_tx} end,
         # the tx read once Format takes the block hash from Model.Block
         find_signed_tx: fn ^tx_hash -> {:value, signed_tx} end,
         get_header: fn ^mb_hash -> header end
       ]},
      {:aec_chain, [:passthrough],
       [
         get_contract_call: fn ^contract_or_name_pk, _call_id, ^mb_hash -> {:ok, call_rec} end
       ]}
    ]
  end

  defp put_origin(state, contract_pk, create_txi),
    do:
      State.put(
        state,
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
      )
end
