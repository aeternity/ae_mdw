defmodule AeMdwWeb.Util do

  def to_tx_type(<<user_tx_type :: binary>>),
    do: user_tx_type |> Macro.underscore |> String.to_existing_atom

  def to_user_tx_type(tx_type) when is_atom(tx_type),
    do: "#{tx_type}" |> Macro.camelize

end
