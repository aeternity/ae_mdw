defmodule AeMdwWeb.Util do
  def to_tx_type(<<user_tx_type::binary>>),
    do: user_tx_type |> Macro.underscore() |> String.to_existing_atom()

  def to_user_tx_type(tx_type) when is_atom(tx_type) do
    case Macro.camelize("#{tx_type}") do
      "Ga" <> rest -> "GA" <> rest
      other -> other
    end
  end

  def pagination(limit, temp), do: StreamSplit.take_and_drop(temp, limit)

  def pagination(limit, 1, temp), do: pagination(limit, temp)

  def pagination(limit, page, temp) do
    {_, temp1} = StreamSplit.take_and_drop(temp, limit * (page - 1))
    pagination(limit, temp1)
  end

  def pagination(_limit, 0, acc, _temp), do: acc

  def pagination(limit, page, acc, temp) do
    {txs_list, temp1} = StreamSplit.take_and_drop(temp, limit)
    pagination(limit, page - 1, [txs_list | acc], temp1)
  end
end
