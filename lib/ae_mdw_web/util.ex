defmodule AeMdwWeb.Util do
  def to_tx_type(<<user_tx_type::binary>>),
    do: user_tx_type |> Macro.underscore() |> String.to_existing_atom()

  def to_user_tx_type(tx_type) when is_atom(tx_type),
    do: "#{tx_type}" |> Macro.camelize()

  def pagination(_limit, 0, acc, _temp), do: acc

  def pagination(limit, page, acc, temp) do
    {txs_list, temp1} = StreamSplit.take_and_drop(temp, limit)
    pagination(limit, page - 1, [txs_list | acc], temp1)
  end
end
