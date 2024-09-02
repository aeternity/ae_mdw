defmodule AeMdw.Node do
  @moduledoc """
  Node module that contains most of the logic for communicating with the node and
  accessing oftenly used information.

  Since this module is used often, most of the functions are defined using Memoize
  for rapid access.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Contract
  alias AeMdw.Contracts
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Extract
  alias AeMdw.Extract.AbsCode
  alias AeMdw.Node.Db

  import AeMdw.Util.Memoize

  @type tx_group :: :channel | :contract | :ga | :name | :oracle | :paying | :spend
  @type tx_type ::
          :spend_tx
          | :oracle_register_tx
          | :oracle_extend_tx
          | :oracle_query_tx
          | :oracle_response_tx
          | :name_preclaim_tx
          | :name_claim_tx
          | :name_transfer_tx
          | :name_update_tx
          | :name_revoke_tx
          | :contract_create_tx
          | :contract_call_tx
          | :ga_attach_tx
          | :ga_meta_tx
          | :channel_create_tx
          | :channel_deposit_tx
          | :channel_withdraw_tx
          | :channel_force_progress_tx
          | :channel_close_mutual_tx
          | :channel_close_solo_tx
          | :channel_slash_tx
          | :channel_settle_tx
          | :channel_snapshot_solo_tx
          | :channel_set_delegates_tx
          | :channel_offchain_tx
          | :channel_client_reconnect_tx
          | :paying_for_tx
  @type height() :: non_neg_integer()
  @type amount() :: non_neg_integer()
  @type id_tag() :: :account | :oracle | :name | :commitment | :contract | :channel
  @type tx_field() :: atom()
  @type tx_field_pos() :: non_neg_integer()
  @type lima_contract() :: %{
          pubkey: Db.pubkey(),
          amount: non_neg_integer(),
          abi_version: non_neg_integer(),
          code: binary(),
          nonce: non_neg_integer(),
          vm_version: non_neg_integer(),
          call_data: binary()
        }
  @type lima_account() :: {pk :: Db.pubkey(), amount :: non_neg_integer()}

  @type hashrate() :: non_neg_integer()
  @type difficulty() :: non_neg_integer()

  @opaque signed_tx() :: tuple()
  @opaque aetx() :: tuple()
  @opaque tx() :: tuple()
  @opaque aect_call :: tuple()

  @type aexn_event_type ::
          :allowance
          | :approval
          | :approval_for_all
          | :burn
          | :mint
          | :swap
          | :edition_limit
          | :edition_limit_decrease
          | :template_creation
          | :template_deletion
          | :template_mint
          | :template_limit
          | :template_limit_decrease
          | :token_limit
          | :token_limit_decrease
          | :transfer

  @typep method_hash :: binary()
  @typep method_signature :: {list(), any()}

  @spec aex9_signatures :: %{method_hash() => method_signature()}
  defmemo aex9_signatures() do
    Contract.aex9_signatures()
    |> map_by_function_hash()
  end

  @spec aex141_signatures :: %{method_hash() => method_signature()}
  defmemo aex141_signatures() do
    Contract.aex141_signatures()
    |> map_by_function_hash()
  end

  @spec previous_aex141_signatures :: %{method_hash() => method_signature()}
  defmemo previous_aex141_signatures() do
    Contract.previous_aex141_signatures()
    |> map_by_function_hash()
  end

  @spec aexn_event_hash_types() :: %{Contracts.event_hash() => aexn_event_type()}
  defmemo aexn_event_hash_types() do
    map_event_hash_to_type(~w(
      allowance
      approval
      approval_for_all
      burn
      mint
      swap
      edition_limit
      edition_limit_decrease
      template_creation
      template_deletion
      template_mint
      template_limit
      template_limit_decrease
      token_limit
      token_limit_decrease
      transfer
    )a)
  end

  @spec aexn_event_names() :: %{Contracts.event_hash() => AexnContracts.event_name()}
  defmemo aexn_event_names() do
    aexn_event_hash_types()
    |> map_event_hash_to_name()
  end

  @spec dex_event_hash_types() :: %{Contracts.event_hash() => aexn_event_type()}
  defmemo dex_event_hash_types() do
    map_event_hash_to_type(~w(
      pair_created
      swap_tokens
    )a)
  end

  @spec dex_event_names() :: %{Contracts.event_hash() => AexnContracts.event_name()}
  defmemo dex_event_names() do
    dex_event_hash_types()
    |> map_event_hash_to_name()
  end

  @spec height_proto() :: [{non_neg_integer(), non_neg_integer()}]
  defmemo height_proto() do
    :aec_hard_forks.protocols() |> Enum.into([]) |> Enum.sort(:desc)
  end

  @spec id_fields :: MapSet.t()
  defmemo id_fields() do
    {_tx_field_types, _tx_fields, tx_ids} = types_fields_ids()

    for {_type, ids_map} <- tx_ids, {field, _pos} <- ids_map, reduce: MapSet.new() do
      acc -> MapSet.put(acc, to_string(field))
    end
  end

  @spec id_prefixes() :: MapSet.t()
  defmemo id_prefixes() do
    aeser_code()
    |> AbsCode.reduce({:pfx2type, 1}, [], fn {:clause, _loc1,
                                              [
                                                {:bin, _loc2,
                                                 [
                                                   {:bin_element, _loc3, {:string, _loc4, pfx},
                                                    _rep_size, _rep_tsl}
                                                 ]}
                                              ], [], [{:atom, _loc5, _type}]},
                                             acc ->
      ["#{pfx}" | acc]
    end)
    |> MapSet.new()
  end

  @spec id_type(atom()) :: id_tag()
  defmemo id_type(id_type) do
    Map.fetch!(id_type(), id_type)
  end

  @spec lima_height :: non_neg_integer()
  defmemo lima_height() do
    :aec_governance.get_network_id()
    |> :aec_hard_forks.protocols_from_network_id()
    |> Enum.find_value(0, fn {vsn, height} ->
      if vsn == :aec_hard_forks.protocol_vsn(:lima), do: height
    end)
  end

  # The calculation is the same as in the node in aehttp_dispatch_ext.erl
  @spec difficulty_to_hashrate(difficulty()) :: hashrate()
  defmemo difficulty_to_hashrate(difficulty) do
    round(difficulty * 42 / :aec_governance.expected_block_mine_rate() / 1000)
  end

  @spec lima_contracts() :: list(lima_contract())
  defmemo lima_contracts() do
    try do
      :aec_fork_block_settings.lima_contracts()
    rescue
      _e in ErlangError ->
        []

      e ->
        reraise(e, __STACKTRACE__)
    end
  end

  @spec lima_accounts() :: list(lima_account())
  defmemo lima_accounts() do
    try do
      :aec_fork_block_settings.lima_accounts()
    rescue
      _e in ErlangError ->
        []

      e ->
        reraise(e, __STACKTRACE__)
    end
  end

  @spec lima_extra_accounts() :: list(lima_account())
  defmemo lima_extra_accounts() do
    try do
      :aec_fork_block_settings.lima_extra_accounts()
    rescue
      _e in ErlangError ->
        []

      e ->
        reraise(e, __STACKTRACE__)
    end
  end

  @spec min_block_reward_height :: height()
  defmemo min_block_reward_height() do
    :aec_block_genesis.height() + :aec_governance.beneficiary_reward_delay() + 1
  end

  @spec token_supply_delta(height()) :: amount()
  defmemo token_supply_delta(height) do
    Map.get(token_supply_delta(), height, 0)
  end

  @spec tx_field_types(tx_field()) :: MapSet.t()
  defmemo tx_field_types(tx_field) do
    {tx_field_types, _tx_fields, _tx_ids} = types_fields_ids()

    Map.fetch!(tx_field_types, tx_field)
  end

  @spec tx_fields(tx_type()) :: [atom()]
  def tx_fields(tx_type) do
    {_tx_field_types, tx_fields, _tx_ids} = types_fields_ids()

    Map.fetch!(tx_fields, tx_type)
  end

  @spec tx_group(tx_group()) :: [tx_type()]
  def tx_group(tx_group) do
    Map.fetch!(tx_groups_map(), tx_group)
  end

  @spec tx_groups :: MapSet.t()
  def tx_groups do
    tx_groups_map()
    |> Map.keys()
    |> MapSet.new()
  end

  @spec tx_ids(tx_type()) :: %{tx_field() => tx_field_pos()}
  def tx_ids(tx_type) do
    {_tx_field_types, _tx_fields, tx_ids} = types_fields_ids()

    Map.fetch!(tx_ids, tx_type)
  end

  @spec tx_ids_positions(tx_type()) :: [tx_field_pos()]
  def tx_ids_positions(tx_type) do
    Map.fetch!(tx_ids_positions(), tx_type)
  end

  @spec inner_field_positions(tx_field()) :: [tx_field_pos()]
  def inner_field_positions(tx_field) do
    inner_field_positions() |> Map.fetch!(tx_field)
  end

  @spec tx_mod(tx_type()) :: module()
  def tx_mod(tx_type) do
    Map.fetch!(tx_mod_map(), tx_type)
  end

  @spec tx_name(tx_type()) :: binary()
  def tx_name(tx_type) do
    :aetx.type_to_swagger_name(tx_type)
  end

  @spec tx_prefixes :: MapSet.t()
  defmemo tx_prefixes() do
    tx_types()
    |> Enum.map(fn tx_type ->
      str = to_string(tx_type)
      # drop "_tx"
      String.slice(str, 0, String.length(str) - 3)
    end)
    |> MapSet.new()
  end

  @spec tx_types :: MapSet.t()
  defmemo tx_types() do
    tx_mod_map()
    |> Map.keys()
    |> MapSet.new()
  end

  defp map_by_function_hash(signatures) do
    Map.new(signatures, fn {k, v} -> {Contract.function_hash(k), v} end)
  end

  defp map_event_hash_to_type(events) do
    Map.new(events, fn event_type ->
      event_name = event_type |> to_string() |> Macro.camelize()
      {:aec_hash.blake2b_256_hash(event_name), event_type}
    end)
  end

  defp map_event_hash_to_name(events) do
    Map.new(events, fn {hash, type} ->
      {hash, Macro.camelize("#{type}")}
    end)
  end

  defmemop tx_mod_map() do
    AbsCode.reduce(aetx_code(), {:type_to_cb, 1}, %{}, fn {:clause, _loc1, [{:atom, _loc2, t}],
                                                           [], [{:atom, _loc3, m}]},
                                                          acc ->
      Map.put(acc, t, m)
    end)
  end

  defmemop types_fields_ids() do
    type_mod_map = tx_mod_map()

    Enum.reduce(type_mod_map, {%{}, %{}, %{}}, fn {type, _tx_mod},
                                                  {tx_field_types, tx_fields, tx_ids} ->
      {fields, ids} =
        Extract.tx_record_info(type, fn tx_type ->
          Map.fetch!(type_mod_map, tx_type)
        end)

      tx_field_types =
        for {id_field, _pos} <- ids, reduce: tx_field_types do
          acc ->
            update_in(acc, [id_field], fn set -> MapSet.put(set || MapSet.new(), type) end)
        end

      {tx_field_types, put_in(tx_fields[type], fields), put_in(tx_ids[type], ids)}
    end)
  end

  defmemop aeser_code() do
    {:ok, mod_code} = AbsCode.module(:aeser_api_encoder)
    mod_code
  end

  defmemop aetx_code() do
    {:ok, mod_code} = AbsCode.module(:aetx)
    mod_code
  end

  defmemop tx_groups_map() do
    type_groups_map =
      ~w(oracle name contract channel spend ga paying)a
      |> Map.new(&{to_string(&1), &1})

    tx_types()
    |> Enum.group_by(&("#{&1}" |> String.split("_") |> List.first()))
    |> Map.new(fn {k, v} -> {Map.fetch!(type_groups_map, k), v} end)
  end

  defmemop id_type() do
    AbsCode.reduce(aeser_code(), {:id2type, 1}, %{}, fn {:clause, _loc1, [{:atom, _loc2, id}], [],
                                                         [{:atom, _loc3, type}]},
                                                        acc ->
      Map.put(acc, id, type)
    end)
  end

  defmemop token_supply_delta() do
    [
      {HardforkPresets.hardfork_height(:genesis), HardforkPresets.mint_sum(:genesis)}
      | :aec_hard_forks.protocols()
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(fn proto ->
          proto_vsn = :aec_hard_forks.protocol_vsn_name(proto)
          {HardforkPresets.hardfork_height(proto_vsn), HardforkPresets.mint_sum(proto_vsn)}
        end)
    ]
    |> Map.new()
  end

  defmemop tx_ids_positions() do
    {_tx_field_types, _tx_fields, tx_ids} = types_fields_ids()

    Map.new(tx_ids, fn {type, field_ids} ->
      {type, Map.values(field_ids)}
    end)
  end

  defmemop inner_field_positions() do
    {_tx_field_types, _tx_fields, tx_ids} = types_fields_ids()

    tx_ids
    |> Map.values()
    |> Enum.flat_map(fn fields_pos_map ->
      Enum.map(fields_pos_map, fn
        {:ga_id, pos} -> {:ga_id, pos}
        {:payer_id, pos} -> {:payer_id, pos}
        {field, pos} -> {field, AeMdw.Fields.field_pos_mask(:ga_meta_tx, pos)}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {field, positions} ->
      {field, Enum.uniq(positions)}
    end)
  end
end
