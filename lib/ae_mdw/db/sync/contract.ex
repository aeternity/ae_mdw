defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.AexnContracts
  alias AeMdw.Db.Channels
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.ContractCreateCacheMutation
  alias AeMdw.Db.Sync.Origin, as: SyncOrigin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model
  require Contract

  @type call_record() :: tuple()

  @nonce_tries_margin 1_000

  @spec events_mutations(
          [Contract.event()],
          Blocks.block_hash(),
          Blocks.block_index(),
          Txs.txi(),
          Db.pubkey()
        ) :: [
          Mutation.t()
        ]
  def events_mutations(events, block_hash, block_index, call_txi, contract_pk) do
    events =
      Enum.filter(
        events,
        &match?(
          {{:internal_call_tx, fname}, %{info: aetx}}
          when is_tuple(aetx) or fname in Contract.contract_create_fnames(),
          &1
        )
      )

    int_calls =
      [nil | events]
      |> Enum.zip(events)
      |> Enum.map(fn
        {prev_event, {{:internal_call_tx, fname}, _info}}
        when fname in Contract.contract_create_fnames() ->
          # Chain.* and Call.* events don't contain the transaction in the event info, can't be indexed as an internal call
          # so this function relies on a property that every Chain.clone and Chain.create
          # always have a previous Call.amount transaction which tranfers tokens
          # from the original contract to the newly created contract.
          {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = prev_event
          {:spend_tx, tx} = :aetx.specialize_type(aetx)
          recipient_id = :aec_spend_tx.recipient_id(tx)
          total_amount = :aec_spend_tx.amount(tx)
          {:account, contract_pk} = :aeser_id.specialize(recipient_id)
          nonce_tries = length(events) + @nonce_tries_margin
          {fname, create_contract_create_aetx(block_hash, contract_pk, total_amount, nonce_tries)}

        {_prev_event, {{:internal_call_tx, fname}, %{info: tx}}} ->
          {fname, tx}
      end)
      |> Enum.with_index(fn {fname, aetx}, local_idx ->
        {tx_type, tx} = :aetx.specialize_type(aetx)

        {local_idx, fname, tx_type, aetx, tx}
      end)

    [
      IntCallsMutation.new(contract_pk, call_txi, int_calls)
      | events_tx_mutations(int_calls, block_index, block_hash, call_txi)
    ]
  end

  @spec aexn_create_contract_mutation(
          Db.pubkey(),
          Blocks.block_hash(),
          Blocks.block_index(),
          Txs.txi_idx()
        ) ::
          nil | AexnCreateContractMutation.t()
  def aexn_create_contract_mutation(
        contract_pk,
        block_hash,
        {height, _mbi} = block_index,
        txi_idx
      ) do
    with {:ok, {type_info, _compiler_vsn, _source_hash}} <- Contract.get_info(contract_pk),
         aexn_type when aexn_type != nil <- get_aexn_type(height, type_info),
         {:ok, aexn_extensions} <-
           AexnContracts.get_extensions(aexn_type, contract_pk, type_info),
         {:ok, aexn_meta_info} <- AexnContracts.call_meta_info(aexn_type, contract_pk, block_hash) do
      if aexn_type == :aex9 or
           (aexn_type == :aex141 and
              AexnContracts.has_valid_aex141_extensions?(aexn_extensions, type_info)) do
        AexnCreateContractMutation.new(
          aexn_type,
          contract_pk,
          aexn_meta_info,
          block_index,
          txi_idx,
          aexn_extensions
        )
      end
    else
      _error_or_nil ->
        nil
    end
  end

  #
  # Private functions
  #
  defp get_aexn_type(height, type_info) do
    cond do
      AexnContracts.aex9?(type_info) -> :aex9
      AexnContracts.has_aex141_signatures?(height, type_info) -> :aex141
      true -> nil
    end
  end

  defp events_tx_mutations(int_calls, {height, _mbi} = block_index, block_hash, call_txi) do
    Enum.map(int_calls, fn
      {local_idx, "Oracle.extend", :oracle_extend_tx, _aetx, tx} ->
        Oracle.extend_mutation(tx, block_index, {call_txi, local_idx})

      {local_idx, "Oracle.register", :oracle_register_tx, _aetx, tx} ->
        Oracle.register_mutations(tx, block_index, {call_txi, local_idx})

      {local_idx, "Oracle.respond", :oracle_response_tx, _aetx, tx} ->
        Oracle.response_mutation(tx, block_index, {call_txi, local_idx})

      {local_idx, "Oracle.query", :oracle_query_tx, _aetx, tx} ->
        Oracle.query_mutation(tx, height, {call_txi, local_idx})

      {local_idx, "AENS.claim", :name_claim_tx, _aetx, tx} ->
        Name.name_claim_mutations(tx, block_index, {call_txi, local_idx})

      {local_idx, "AENS.update", :name_update_tx, _aetx, tx} ->
        Name.update_mutations(tx, {call_txi, local_idx}, block_index, true)

      {local_idx, "AENS.transfer", :name_transfer_tx, _aetx, tx} ->
        NameTransferMutation.new(tx, {call_txi, local_idx})

      {local_idx, "AENS.revoke", :name_revoke_tx, _aetx, tx} ->
        tx
        |> :aens_revoke_tx.name_hash()
        |> NameRevokeMutation.new({call_txi, local_idx}, block_index)

      {local_idx, "Channel.withdraw", :channel_withdraw_tx, _aetx, tx} ->
        Channels.withdraw_mutations({block_index, {call_txi, local_idx}}, tx)

      {local_idx, "Channel.settle", :channel_settle_tx, _aetx, tx} ->
        Channels.settle_mutations({block_index, {call_txi, local_idx}}, tx)

      {local_idx, fname, :contract_create_tx, _aetx, tx}
      when fname in Contract.contract_create_fnames() ->
        contract_pk = :aect_create_tx.contract_pubkey(tx)

        [
          aexn_create_contract_mutation(
            contract_pk,
            block_hash,
            block_index,
            {call_txi, local_idx}
          ),
          ContractCreateCacheMutation.new(contract_pk, call_txi)
          | SyncOrigin.origin_mutations(
              :contract_call_tx,
              nil,
              contract_pk,
              {call_txi, local_idx}
            )
        ]

      {_local_idx, _fname, _tx_type, _aetx, _tx} ->
        []
    end)
  end

  defp create_contract_create_aetx(block_hash, contract_pk, initial_amount, nonce_tries) do
    {:ok, contract, code} = :aec_chain.get_contract_with_code(contract_pk)
    owner_id = :aect_contracts.owner_id(contract)
    deposit = :aect_contracts.deposit(contract)
    abi_version = :aect_contracts.abi_version(contract)
    vm_version = :aect_contracts.vm_version(contract)
    {_tag, owner_pk} = :aeser_id.specialize(owner_id)
    owner_nonce = Db.nonce_at_block(block_hash, owner_pk)
    nonce_tries = owner_nonce..(owner_nonce + nonce_tries)

    nonce =
      Enum.find(
        nonce_tries,
        &(:aect_contracts.compute_contract_pubkey(owner_pk, &1) == contract_pk)
      )

    unless nonce do
      raise "nonce not found for #{Enc.encode(:contract_pubkey, contract_pk)} owner #{Enc.encode(:account_pubkey, owner_pk)}"
    end

    {:ok, contract_create_aetx} =
      :aect_create_tx.new(%{
        owner_id: owner_id,
        nonce: nonce,
        code: code,
        vm_version: vm_version,
        abi_version: abi_version,
        deposit: deposit,
        amount: initial_amount - deposit,
        gas: 0,
        gas_price: 0,
        call_data: <<43, 17, 68, 214, 68, 31, 59, 36, 2, 0>>,
        fee: 0
      })

    contract_create_aetx
  end
end
