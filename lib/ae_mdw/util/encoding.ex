defmodule AeMdw.Util.Encoding do
  @moduledoc """
  Encodes and decodes accounts, contracts, hashes and other ids.
  """

  alias AeMdw.Db.State
  alias AeMdw.Txs

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @spec encode_contract(pubkey() | nil) :: String.t()
  def encode_contract(nil), do: nil
  def encode_contract(pk), do: :aeser_api_encoder.encode(:contract_pubkey, pk)

  @spec encode_account(pubkey() | nil) :: String.t()
  def encode_account(nil), do: nil
  def encode_account(pk), do: :aeser_api_encoder.encode(:account_pubkey, pk)

  @spec encode_to_hash(State.t(), AeMdw.Blocks.txi_pos()) :: String.t()
  def encode_to_hash(state, txi) when txi > 0 do
    tx_hash = Txs.txi_to_hash(state, txi)
    :aeser_api_encoder.encode(:tx_hash, tx_hash)
  end

  def encode_to_hash(_state, _txi), do: nil

  @spec encode_block(atom(), binary()) :: String.t()
  def encode_block(:key, hash), do: :aeser_api_encoder.encode(:key_block_hash, hash)
  def encode_block(:micro, hash), do: :aeser_api_encoder.encode(:micro_block_hash, hash)

  @spec encode(atom(), pubkey()) :: String.t()
  defdelegate encode(type, pk), to: :aeser_api_encoder
end
