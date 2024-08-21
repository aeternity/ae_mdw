defmodule AeMdw.Migrations.CreateClaimCallsTable do
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Util

  require Model
  require Logger

  # @min_int Util.min_int()
  @max_int Util.max_int()
  @min_bin Util.min_bin()
  @max_bin Util.max_256bit_bin()

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    IO.inspect("Started", label: "Field count")

    field_count =
      Collection.stream(
        state,
        Model.Field,
        :backward,
        {{:name_claim_tx, -1, "", {-1, -1}},
         {:name_claim_tx, @max_int, @max_bin, {@max_int, @max_int}}},
        nil
      )
      |> Enum.count()

    IO.inspect(field_count, label: "Field count")

    {count, _state} =
      state
      |> Collection.stream(
        Model.Field,
        :backward,
        {{:name_claim_tx, -1, "", {-1, -1}},
         {:name_claim_tx, @max_int, @max_bin, {@max_int, @max_int}}},
        nil
      )
      |> Stream.flat_map(fn {_tx_type, _tx_field_pos, account_pk, call_idx} ->
        [
          Collection.stream(
            state,
            Model.NameClaim,
            :backward,
            {{@min_bin, -1, call_idx}, {@max_bin, @max_int, call_idx}},
            nil
          ),
          Collection.stream(
            state,
            Model.AuctionBidClaim,
            :backward,
            {{@min_bin, -1, call_idx}, {@max_bin, @max_int, call_idx}},
            nil
          )
        ]
        |> Collection.merge(:backward)
        |> Stream.map(fn {plain_name, height, call_idx} ->
          {account_pk, call_idx, height, plain_name}
        end)
      end)
      |> Enum.reduce({0, state}, fn {account_pk, call_idx, height, plain_name},
                                    {count, state_acc} ->
        Logger.info("Started claim call #{count + 1} out of #{field_count}")

        {count + 1,
         State.put(
           state_acc,
           Model.ClaimCall,
           Model.claim_call(index: {account_pk, call_idx, height, plain_name})
         )}
      end)

    if count == field_count do
      raise "Claim calls count mismatch"
    end

    {:ok, count}
  end
end
