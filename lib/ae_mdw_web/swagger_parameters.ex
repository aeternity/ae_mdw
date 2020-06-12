defmodule AeMdwWeb.SwaggerParameters do
  @moduledoc "Common parameter declarations for phoenix swagger"

  alias PhoenixSwagger.Path.PathObject
  import PhoenixSwagger.Path

  def common_params(path = %PathObject{}) do
    path
    |> parameter(
      :type,
      :query,
      :array,
      "The transaction type. The query allows providing of multiple type parameters. [More info](https://github.com/aeternity/ae_mdw#types).",
      items: [
        type: :string,
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
        ]
      ],
      collectionFormat: :multi,
      required: false,
      example: "channel_create"
    )
    |> parameter(
      :type_group,
      :query,
      :array,
      "The type group. The query allows providing of multiple type group parameters. [More info](https://github.com/aeternity/ae_mdw#types).",
      items: [
        type: :string,
        enum: [:channel, :contract, :ga, :name, :oracle, :paying_for, :spend]
      ],
      collectionFormat: :multi,
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
    |> parameter(:page, :query, :integer, "The number of page to show.",
      required: false,
      format: "int32",
      default: 1,
      example: 1
    )
    |> parameter(
      :limit,
      :query,
      :integer,
      "The numbers of items to return.",
      required: false,
      format: "int32",
      default: 10,
      minimum: 1,
      maximum: 1000,
      example: 10
    )
  end
end
