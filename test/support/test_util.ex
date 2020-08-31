defmodule AeMdwWeb.TestUtil do
  alias AeMdw.Error.Input, as: ErrInput

  def handle_input(f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        err.message
    end
  end
end
