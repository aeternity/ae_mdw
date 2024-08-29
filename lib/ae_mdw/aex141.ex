defmodule AeMdw.Aex141 do
  @moduledoc """
  Returns NFT info interacting with AEX-141 contracts or from transfer history.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Stats
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdw.Util.Encoding

  require Model

  @typep pagination :: Collection.direction_limit()
  @typep cursor :: binary() | nil
  @typep page_cursor :: Collection.pagination_cursor()
  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep limit :: integer() | nil
  @type limits :: %{
          token_limit: limit(),
          template_limit: limit(),
          limit_txi: Txs.txi() | nil,
          limit_log_idx: non_neg_integer() | nil
        }

  @type token_id :: integer()
  @type template_id :: integer()
  @type nft :: %{
          contract_id: String.t(),
          owner_id: String.t(),
          token_id: token_id()
        }
  @type template_nft :: %{
          token_id: token_id(),
          owner_id: String.t(),
          tx_hash: Txs.tx_hash(),
          log_idx: AeMdw.Contracts.log_idx()
        }
  @type opt() :: {:v3?, boolean()}
  @type opts() :: [opt()]

  @type metadata :: %{url: String.t()} | %{id: String.t()} | %{map: map()}

  @ownership_table Model.NftOwnership
  @templates_table Model.NftTemplate
  @template_tokens_table Model.NftTemplateToken
  @owners_table Model.NftTokenOwner

  @spec fetch_nft_metadata(State.t(), pubkey(), token_id()) ::
          {:ok, metadata()} | {:error, Error.t()}
  def fetch_nft_metadata(state, contract_pk, token_id) do
    with {:ok, Model.aexn_contract(meta_info: {_name, _symbol, _url, metadata_type})} <-
           get_contract(state, contract_pk),
         {:ok, return} <- call_contract(contract_pk, "metadata", [token_id]) do
      decode_metadata(metadata_type, return)
    end
  end

  @spec fetch_nft(State.t(), binary(), binary(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def fetch_nft(state, contract_id, token_id, opts) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:int, {token_id, ""}} <- {:int, Integer.parse(token_id)},
         {:ok, Model.aexn_contract(meta_info: {_name, _symbol, _url, metadata_type})} <-
           get_contract(state, contract_pk),
         {:owner, {:ok, {:address, account_pk}}} <-
           {:owner, call_contract(contract_pk, "owner", [token_id])} do
      {:ok, render_nft(contract_pk, account_pk, token_id, metadata_type, opts)}
    else
      :error ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      {:int, _invalid_int} ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: token_id)}

      {:owner, {:ok, mismatch}} ->
        {:error, ErrInput.ContractReturn.exception(value: inspect(mismatch))}

      {:owner, {:error, reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def render_nft(contract_pk, account_pk, token_id, metadata_type, opts) do
    if Keyword.get(opts, :v3?, true) do
      render_nft(contract_pk, account_pk, token_id, metadata_type)
    else
      render_nft_v2(contract_pk, account_pk, token_id, metadata_type)
    end
  end

  defp render_nft(contract_pk, account_pk, token_id, metadata_type) do
    {:ok, return_metadata} = call_contract(contract_pk, "metadata", [token_id])
    {:ok, decoded_metadata} = decode_metadata(metadata_type, return_metadata)

    %{
      token_id: token_id,
      owner: encode_account(account_pk),
      metadata: decoded_metadata
    }
  end

  defp render_nft_v2(_contract_pk, account_pk, _token_id, _metadata_type) do
    %{data: encode_account(account_pk)}
  end

  @spec fetch_owned_tokens(State.t(), binary(), cursor(), pagination(), map()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_owned_tokens(state, account_id, cursor, pagination, params) do
    with {:ok, account_pk} <- Validate.id(account_id),
         {:ok, filters} <- Util.convert_params(params, &convert_owned_tokens_param/1),
         {:ok, cursor} <- deserialize_ownership_cursor(account_pk, cursor) do
      paginated_nfts =
        state
        |> build_owned_tokens_streamer(account_pk, cursor, filters)
        |> Collection.paginate(pagination, &render_owned_nft/1, &serialize_ownership_cursor/1)

      {:ok, paginated_nfts}
    end
  end

  @spec fetch_templates(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_templates(state, account_pk, cursor, pagination) do
    with {:ok, cursor_key} <- deserialize_cursor(@templates_table, cursor) do
      paginated_templates =
        state
        |> build_streamer(@templates_table, cursor_key, account_pk)
        |> Collection.paginate(pagination, &render_template(state, &1), &serialize_cursor/1)

      {:ok, paginated_templates}
    end
  end

  @spec fetch_template_tokens(State.t(), pubkey(), template_id(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [template_nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_template_tokens(state, contract_pk, template_id, cursor, pagination) do
    with {:ok, cursor_key} <- deserialize_cursor(@template_tokens_table, cursor) do
      paginated_template_tokens =
        state
        |> build_streamer(@template_tokens_table, cursor_key, {contract_pk, template_id})
        |> Collection.paginate(pagination, &render_template_token(state, &1), &serialize_cursor/1)

      {:ok, paginated_template_tokens}
    end
  end

  @spec fetch_collection_owners(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_collection_owners(state, contract_pk, cursor, pagination) do
    with true <- State.exists?(state, Model.AexnContract, {:aex141, contract_pk}),
         {:ok, cursor_key} <- deserialize_cursor(@owners_table, cursor) do
      paginated_owners =
        state
        |> build_streamer(@owners_table, cursor_key, contract_pk)
        |> Collection.paginate(pagination, &render_owner(state, &1), &serialize_cursor/1)

      {:ok, paginated_owners}
    else
      false ->
        {:error, ErrInput.NotFound.exception(value: contract_pk)}

      cursor_error ->
        cursor_error
    end
  end

  @spec fetch_limits(State.t(), pubkey(), boolean()) :: limits() | nil
  def fetch_limits(state, contract_pk, v3?) do
    Model.nft_contract_limits(
      token_limit: token_limit,
      template_limit: template_limit,
      txi: txi,
      log_idx: log_idx
    ) =
      case State.get(state, Model.NftContractLimits, contract_pk) do
        :not_found -> Model.nft_contract_limits()
        {:ok, m_limits} -> m_limits
      end

    if token_limit != nil or template_limit != nil do
      response = %{
        token_limit: token_limit,
        template_limit: template_limit,
        limit_txi: txi,
        limit_log_idx: log_idx
      }

      if v3? do
        response
        |> Map.put(:limit_tx_hash, Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi)))
        |> Map.delete(:limit_txi)
      else
        response
      end
    end
  end

  #
  # Private function
  #
  defp build_owned_tokens_streamer(state, account_pk, cursor, %{contract: contract_pk}) do
    key_boundary =
      {{account_pk, contract_pk, Util.min_int()}, {account_pk, contract_pk, Util.max_int()}}

    fn direction ->
      Collection.stream(state, @ownership_table, direction, key_boundary, cursor)
    end
  end

  defp build_owned_tokens_streamer(state, account_pk, cursor, _params) do
    key_boundary = {{account_pk, <<>>, 0}, {account_pk, Util.max_256bit_bin(), Util.max_int()}}

    fn direction ->
      Collection.stream(state, @ownership_table, direction, key_boundary, cursor)
    end
  end

  defp build_streamer(state, Model.NftTemplateToken, cursor_key, {contract_pk, template_id}) do
    key_boundary = {{contract_pk, template_id, -1}, {contract_pk, template_id, nil}}

    fn direction ->
      Collection.stream(state, Model.NftTemplateToken, direction, key_boundary, cursor_key)
    end
  end

  defp build_streamer(state, table, cursor_key, pubkey) do
    key_boundary = {{pubkey, Util.min_256bit_int()}, {pubkey, nil}}

    fn direction ->
      Collection.stream(state, table, direction, key_boundary, cursor_key)
    end
  end

  defp serialize_cursor(cursor), do: cursor |> :erlang.term_to_binary() |> Base.encode64()

  defp deserialize_cursor(_table, nil), do: {:ok, nil}

  defp deserialize_cursor(Model.NftTemplate, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, template_id} = cursor when is_integer(template_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_cursor(Model.NftTemplateToken, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, template_id, token_id} = cursor
         when is_integer(template_id) and is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_cursor(Model.NftTokenOwner, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, token_id} = cursor when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp serialize_ownership_cursor({_account_pk, contract_pk, token_id}),
    do: serialize_cursor({contract_pk, token_id})

  defp deserialize_ownership_cursor(_account_pk, nil), do: {:ok, nil}

  defp deserialize_ownership_cursor(account_pk, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>> = contract_pk, token_id} when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {account_pk, contract_pk, token_id}}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp convert_owned_tokens_param({"contract", contract_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id) do
      {:ok, {:contract, contract_pk}}
    end
  end

  defp convert_owned_tokens_param(other_param),
    do: {:error, ErrInput.Query.exception(value: other_param)}

  defp get_contract(state, contract_pk) do
    with :not_found <- State.get(state, Model.AexnContract, {:aex141, contract_pk}) do
      {:error, ErrInput.NotAex141.exception(value: encode_contract(contract_pk))}
    end
  end

  defp call_contract(contract_pk, entrypoint, args) do
    case AexnContracts.call_contract(contract_pk, entrypoint, args) do
      {:ok, {:variant, [0, 1], 1, {result}}} ->
        {:ok, result}

      {:error, _reason} ->
        {:error, ErrInput.ContractDryRun.exception(value: encode_contract(contract_pk))}

      {:ok, unknown_return} ->
        {:error, ErrInput.ContractReturn.exception(value: inspect(unknown_return))}
    end
  end

  defp decode_metadata(meta_info_type, return) do
    case return do
      {:variant, [1, 1], 0, {metadata}} ->
        {:ok, %{meta_info_type => metadata}}

      {:variant, [1, 1], 1, {metadata}} ->
        {:ok, %{map: metadata}}

      mismatch ->
        {:error, ErrInput.ContractReturn.exception(value: inspect(mismatch))}
    end
  end

  defp render_owned_nft({owner_pk, contract_pk, token_id}) do
    %{
      contract_id: encode_contract(contract_pk),
      owner_id: encode_account(owner_pk),
      token_id: token_id
    }
  end

  defp render_template(state, {contract_pk, template_id}) do
    Model.nft_template(txi: txi, log_idx: log_idx, limit: limit) =
      State.fetch!(state, @templates_table, {contract_pk, template_id})

    tx_hash = Txs.txi_to_hash(state, txi)

    %{
      contract_id: encode_contract(contract_pk),
      template_id: template_id,
      tx_hash: encode(:tx_hash, tx_hash),
      log_idx: log_idx,
      edition: render_template_edition(state, contract_pk, template_id, limit)
    }
  end

  defp render_template_token(state, {contract_pk, template_id, token_id}) do
    Model.nft_template_token(txi: txi, log_idx: log_idx, edition: edition) =
      State.fetch!(state, @template_tokens_table, {contract_pk, template_id, token_id})

    Model.nft_token_owner(owner: owner_pk) =
      State.fetch!(state, @owners_table, {contract_pk, token_id})

    tx_hash = Txs.txi_to_hash(state, txi)

    %{
      edition: edition,
      token_id: token_id,
      owner_id: encode_account(owner_pk),
      tx_hash: encode(:tx_hash, tx_hash),
      log_idx: log_idx
    }
  end

  defp render_template_edition(state, contract_pk, template_id, limit) do
    stats_key = Stats.nft_template_tokens_key(contract_pk, template_id)

    if nil != limit or State.exists?(state, Model.Stat, stats_key) do
      state
      |> render_template_edition_limit(limit)
      |> Map.merge(render_template_edition_supply(state, contract_pk, template_id))
    end
  end

  defp render_template_edition_limit(_state, nil), do: %{}

  defp render_template_edition_limit(state, {amount, txi, log_idx}) do
    tx_hash = Txs.txi_to_hash(state, txi)

    %{
      limit: amount,
      limit_log_idx: log_idx,
      limit_tx_hash: encode(:tx_hash, tx_hash)
    }
  end

  defp render_template_edition_supply(state, contract_pk, template_id) do
    with {:ok, Model.stat(payload: amount)} <-
           State.get(state, Model.Stat, Stats.nft_template_tokens_key(contract_pk, template_id)),
         {:ok, {^contract_pk, ^template_id, _token_id} = prev_key} <-
           State.prev(state, Model.NftTemplateToken, {contract_pk, template_id, nil}),
         {:ok, Model.nft_template_token(txi: txi, log_idx: log_idx)} <-
           State.get(state, Model.NftTemplateToken, prev_key) do
      tx_hash = Txs.txi_to_hash(state, txi)

      %{
        supply: amount,
        supply_log_idx: log_idx,
        supply_tx_hash: encode(:tx_hash, tx_hash)
      }
    else
      _mismatch_or_not_found ->
        %{
          supply: 0,
          supply_log_idx: nil,
          supply_tx_hash: nil
        }
    end
  end

  defp render_owner(state, {contract_pk, token_id} = key) do
    Model.nft_token_owner(owner: owner_pk) = State.fetch!(state, @owners_table, key)

    %{
      contract_id: encode_contract(contract_pk),
      owner_id: encode_account(owner_pk),
      token_id: token_id
    }
  end
end
