defmodule AeMdwWeb.SwaggerParameters do
  @moduledoc "Common parameter declarations for phoenix swagger"

  alias PhoenixSwagger.Path.PathObject
  import PhoenixSwagger.Path

  def common_params(path = %PathObject{}) do
    path
    |> parameter(
      :type,
      :query,
      :string,
      "The transaction type. [Supported types](https://github.com/aeternity/ae_mdw#supported-types).",
      enum: [
        :channel_close_mutual,
        :channel_close_solo,
        :channel_create,
        :channel_deposit,
        :channel_force_progress,
        :channel_offchain,
        :channel_settle,
        :channel_slash,
        :channel_snapshot_solo,
        :channel_withdraw,
        :contract_call,
        :contract_create,
        :ga_attach,
        :ga_meta,
        :name_claim,
        :name_preclaim,
        :name_revoke,
        :name_transfer,
        :name_update,
        :oracle_extend,
        :oracle_query,
        :oracle_register,
        :oracle_response,
        :paying_for,
        :spend
      ],
      required: false,
      example: "channel_create"
    )
    |> parameter(
      :type_group,
      :query,
      :string,
      "The type group. [Supported type groups](https://github.com/aeternity/ae_mdw#supported-type-groups).",
      enum: [:channel, :contract, :ga, :name, :oracle, :paying_for, :spend],
      required: false,
      example: "channel"
    )
    |> parameter(
      :account,
      :query,
      :string,
      "The account ID. [More info](https://github.com/aeternity/ae_mdw#generic-ids).",
      required: false,
      example: "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"
    )
    |> parameter(
      :contract,
      :query,
      :string,
      "The contract ID. [More info](https://github.com/aeternity/ae_mdw#generic-ids).",
      required: false,
      example: "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
    )
    |> parameter(
      :channel,
      :query,
      :string,
      "The channel ID. [More info](https://github.com/aeternity/ae_mdw#generic-ids).",
      required: false,
      example: "ch_22usvXSjYaDPdhecyhub7tZnYpHeCEZdscEEyhb2M4rHb58RyD"
    )
    |> parameter(
      :oracle,
      :query,
      :string,
      "The oracle ID. [More info](https://github.com/aeternity/ae_mdw#generic-ids).",
      required: false,
      example: "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
    )
    # |> parameter(:name, :query, :string, "The name ID.", required: false, example: )
    |> parameter(:page, :query, :integer, "The number of page to show, by default is set to 1.",
      required: false,
      format: "int32",
      example: 1
    )
    |> parameter(
      :limit,
      :query,
      :integer,
      "Max limit number of results, which are returned in a result. Default is 10.",
      required: false,
      format: "int32",
      example: 10
    )
  end
end
