defmodule AeMdw.Node.AexnEventFixtures do
  @moduledoc false

  @type aexn_event_type :: AeMdw.Node.aexn_event_type()
  @type event_hash :: AeMdw.Node.event_hash()

  @spec aexn_event_hash(aexn_event_type()) :: [event_hash()]
  def aexn_event_hash(:burn), do: :aec_hash.blake2b_256_hash("Burn")
  def aexn_event_hash(:mint), do: :aec_hash.blake2b_256_hash("Mint")
  def aexn_event_hash(:swap), do: :aec_hash.blake2b_256_hash("Swap")
  def aexn_event_hash(:transfer), do: :aec_hash.blake2b_256_hash("Transfer")
  def aexn_event_hash(:template_creation), do: :aec_hash.blake2b_256_hash("TemplateCreation")
  def aexn_event_hash(:template_deletion), do: :aec_hash.blake2b_256_hash("TemplateDeletion")
  def aexn_event_hash(:template_mint), do: :aec_hash.blake2b_256_hash("TemplateMint")
  def aexn_event_hash(:template_limit), do: :aec_hash.blake2b_256_hash("TemplateLimit")

  def aexn_event_hash(:template_limit_decrease),
    do: :aec_hash.blake2b_256_hash("TemplateLimitDecrease")

  def aexn_event_hash(:token_limit), do: :aec_hash.blake2b_256_hash("TokenLimit")
  def aexn_event_hash(:token_limit_decrease), do: :aec_hash.blake2b_256_hash("TokenLimitDecrease")
end
