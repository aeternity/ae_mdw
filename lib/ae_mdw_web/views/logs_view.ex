defmodule AeMdwWeb.LogsView do
  @moduledoc false

  alias AeMdw.AexnContracts
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DBUtil

  import AeMdw.Util.Encoding

  require Model

  @type opts :: %{aexn_args: boolean(), custom_args: boolean()}

  @spec render_log(State.t(), AeMdw.Contracts.log(), opts()) :: map()
  def render_log(state, {create_txi, call_txi, log_idx} = index, encode_args) do
    {contract_tx_hash, ct_pk} =
      if create_txi == -1 do
        {nil, Origin.pubkey(state, {:contract_call, call_txi})}
      else
        {encode_to_hash(state, create_txi), Origin.pubkey(state, {:contract, create_txi})}
      end

    Model.tx(id: call_tx_hash, block_index: {height, micro_index}) =
      State.fetch!(state, Model.Tx, call_txi)

    Model.block(hash: block_hash) = DBUtil.read_block!(state, {height, micro_index})

    Model.contract_log(args: args, data: data, ext_contract: ext_contract, hash: event_hash) =
      read_log(state, index)

    event_name = AexnContracts.event_name(event_hash) || get_custom_event_name(event_hash)

    state
    |> render_remote_log_fields(ext_contract)
    |> Map.merge(%{
      contract_txi: create_txi,
      contract_tx_hash: contract_tx_hash,
      contract_id: encode_contract(ct_pk),
      call_txi: call_txi,
      call_tx_hash: encode(:tx_hash, call_tx_hash),
      block_time: DBUtil.block_time(block_hash),
      args: format_args(event_name, args, encode_args),
      data: maybe_encode_base64(data),
      event_hash: Base.hex_encode32(event_hash),
      event_name: event_name,
      height: height,
      micro_index: micro_index,
      block_hash: encode(:micro_block_hash, block_hash),
      log_idx: log_idx
    })
  end

  defp render_remote_log_fields(_state, nil) do
    %{
      ext_caller_contract_txi: -1,
      ext_caller_contract_tx_hash: nil,
      ext_caller_contract_id: nil,
      parent_contract_id: nil
    }
  end

  defp render_remote_log_fields(_state, {:parent_contract_pk, parent_pk}) do
    %{
      ext_caller_contract_txi: -1,
      ext_caller_contract_tx_hash: nil,
      ext_caller_contract_id: nil,
      parent_contract_id: encode_contract(parent_pk)
    }
  end

  defp render_remote_log_fields(state, ext_ct_pk) do
    ext_ct_txi = Origin.tx_index!(state, {:contract, ext_ct_pk})
    ext_ct_tx_hash = encode_to_hash(state, ext_ct_txi)

    %{
      ext_caller_contract_txi: ext_ct_txi,
      ext_caller_contract_tx_hash: ext_ct_tx_hash,
      ext_caller_contract_id: encode_contract(ext_ct_pk),
      parent_contract_id: nil
    }
  end

  defp maybe_encode_base64(data) do
    if String.valid?(data), do: data, else: Base.encode64(data)
  end

  defp format_args("Allowance", [account1, account2, <<amount::256>>], %{aexn_args: true}) do
    [encode_account(account1), encode_account(account2), amount]
  end

  defp format_args("Approval", [account1, account2, <<token_id::256>>, enable], %{aexn_args: true})
       when enable in ["true", "false"] do
    [encode_account(account1), encode_account(account2), token_id, enable]
  end

  defp format_args("ApprovalForAll", [account1, account2, enable], %{aexn_args: true})
       when enable in ["true", "false"] do
    [encode_account(account1), encode_account(account2), enable]
  end

  defp format_args(event_name, [account, <<token_id::256>>], %{aexn_args: true})
       when event_name in ["Burn", "Mint", "Swap"] do
    [encode_account(account), token_id]
  end

  defp format_args("PairCreated", [pair_pk, token1, token2], %{aexn_args: true}) do
    [encode_contract(pair_pk), encode_contract(token1), encode_contract(token2)]
  end

  defp format_args("Transfer", [from, to, <<token_id::256>>], %{aexn_args: true}) do
    [encode_account(from), encode_account(to), token_id]
  end

  defp format_args(
         "TemplateMint",
         [account, <<template_id::256>>, <<token_id::256>>],
         %{aexn_args: true}
       ) do
    [encode_account(account), template_id, token_id]
  end

  defp format_args(
         "TemplateMint",
         [account, <<template_id::256>>, <<token_id::256>>, edition_serial],
         %{aexn_args: true}
       ) do
    [encode_account(account), template_id, token_id, edition_serial]
  end

  defp format_args(event_name, args, %{custom_args: true}) do
    case :persistent_term.get({__MODULE__, event_name}, nil) do
      nil ->
        Enum.map(args, fn <<topic::256>> -> to_string(topic) end)

      custom_args_config ->
        encode_custom_args(args, custom_args_config)
    end
  end

  defp format_args(_event_name, args, _format_opts) do
    Enum.map(args, fn <<topic::256>> -> to_string(topic) end)
  end

  defp encode_custom_args(args, custom_args_config) do
    Enum.with_index(args, fn arg, i ->
      case Map.get(custom_args_config, i) do
        nil ->
          <<topic::256>> = arg
          to_string(topic)

        type ->
          encode(type, arg)
      end
    end)
  end

  defp get_custom_event_name(event_hash) do
    :persistent_term.get({__MODULE__, event_hash}, nil)
  end

  defp read_log(state, index) do
    table = Model.ContractLog

    try do
      State.fetch!(state, table, index)
    rescue
      ArgumentError ->
        {:ok, value} = AeMdw.Db.RocksDb.get(table, :sext.encode(index))
        record_type = Model.record(table)

        value
        |> :sext.decode()
        |> Tuple.insert_at(0, index)
        |> Tuple.insert_at(0, record_type)
    end
  end
end
