defmodule AeMdwWeb.Contract do
  alias AeMdw.EtsCache
  import AeMdw.Util

  @tab AeMdwWeb.Contract

  ################################################################################

  def table(), do: @tab

  def get_info(pubkey) do
    case EtsCache.get(@tab, pubkey) do
      {info, _tm} ->
        info
      nil ->
        code =
          ok!(:aec_chain.get_contract(pubkey))
          |> :aect_contracts.code
          |> :aeser_contract_code.deserialize

        info =
          case code do
            %{type_info: [], byte_code: byte_code} ->
              :aeb_fate_code.deserialize(byte_code)
            %{type_info: type_info} ->
              type_info
          end

        EtsCache.put(@tab, pubkey, info)
        info
    end
  end

  # def decode_calldata(<<_::256>> = pubkey, calldata),
  #   do: decode_calldata(get_info(pubkey), calldata)
  # def decode_calldata(%{type_info: [], byte_code: bytecode}, calldata)

end
