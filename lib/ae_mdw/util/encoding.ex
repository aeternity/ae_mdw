defmodule AeMdw.Util.Encoding do
  @moduledoc """
  Encodes and decodes accounts, contracts, hashes and other ids.
  """

  alias AeMdw.Db.State
  alias AeMdw.Txs
  alias AeMdw.Node.Db

  @type encoded_hash() :: binary()
  @typep pubkey :: Db.pubkey()

  @spec encode(atom(), pubkey()) :: encoded_hash()
  defdelegate encode(type, pk), to: :aeser_api_encoder

  @spec encode_contract(pubkey() | nil) :: encoded_hash()
  def encode_contract(nil), do: nil
  def encode_contract(pk), do: encode(:contract_pubkey, pk)

  @spec encode_account(pubkey() | nil) :: encoded_hash()
  def encode_account(nil), do: nil
  def encode_account(pk), do: encode(:account_pubkey, pk)

  @spec encode_to_hash(State.t(), Txs.txi()) :: encoded_hash()
  def encode_to_hash(state, txi) when txi > 0 do
    tx_hash = Txs.txi_to_hash(state, txi)
    encode(:tx_hash, tx_hash)
  end

  def encode_to_hash(_state, _txi), do: nil

  @spec encode_block(atom(), binary()) :: encoded_hash()
  def encode_block(:key, hash), do: encode(:key_block_hash, hash)
  def encode_block(:micro, hash), do: encode(:micro_block_hash, hash)
end
