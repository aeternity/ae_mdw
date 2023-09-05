defmodule AeMdw.Node.AexnEventFixtures do
  @moduledoc false

  @type aexn_event_type :: AeMdw.Node.aexn_event_type()
  @type event_hash :: AeMdw.Node.event_hash()

  @event_types [
    :allowance,
    :approval,
    :approval_for_all,
    :burn,
    :mint,
    :swap,
    :edition_limit,
    :edition_limit_decrease,
    :template_creation,
    :template_deletion,
    :template_mint,
    :template_limit,
    :template_limit_decrease,
    :token_limit,
    :token_limit_decrease,
    :transfer
  ]

  @spec aexn_event_hash(aexn_event_type()) :: [event_hash()]
  def aexn_event_hash(event_type) when event_type in @event_types do
    event_type
    |> to_string()
    |> Macro.camelize()
    |> :aec_hash.blake2b_256_hash()
  end
end
