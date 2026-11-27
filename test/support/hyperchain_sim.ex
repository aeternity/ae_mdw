defmodule AeMdw.HyperchainSim do
  @moduledoc """
  A simulated hyperchain node, described by its epochs: who validates each one
  with which stake, who leads each of its heights, and its seed when the chain
  already knows it.

  `mock!/1` fakes the node only where it reaches its chain: the key blocks, the
  election contract, the parent chain entropy and the user config. Everything
  above runs for real, including the node's own `:aec_chain_hc` decoding.

  Epoch 1 starts at height 1 and every epoch starts right after the previous
  one. Like the node, whose `step_eoe` moves the election contract on at an
  epoch's last height, the state of a key block already holds the epoch of the
  next height. So the last epoch must end after `:top`.
  """

  alias AeMdw.Node.Db

  @genesis_time 1_700_000_000_000
  @block_time 3_000
  @hash_tag 0xEE
  @hc_config_paths [["chain", "consensus"], ["chain", "hard_forks"], ["fork_management"]]

  @typep pubkey() :: Db.pubkey()
  @typep height() :: non_neg_integer()
  @type epoch_spec() :: %{
          seed: binary() | nil,
          validators: [{pubkey(), non_neg_integer()}],
          schedule: [pubkey()]
        }
  @type epoch() :: %{
          epoch: pos_integer(),
          first: height(),
          last: height(),
          length: pos_integer(),
          seed: binary() | nil,
          validators: [{pubkey(), non_neg_integer()}],
          schedule: [pubkey()]
        }
  @type t() :: %{epochs: [epoch()], top: height(), config: map()}

  @doc """
  Options: `:top` (required), the height of the last key block, and `:config`,
  the node's user config (`default_config/0` when left out).
  """
  @spec new([epoch_spec()], keyword()) :: t()
  def new(epoch_specs, opts) do
    {epochs, _next_first} =
      epoch_specs
      |> Enum.with_index(1)
      |> Enum.map_reduce(1, fn {%{seed: _seed, validators: _vals, schedule: schedule} = spec,
                                number},
                               first ->
        epoch_length = length(schedule)
        last = first + epoch_length - 1

        {Map.merge(spec, %{epoch: number, first: first, last: last, length: epoch_length}),
         last + 1}
      end)

    %{
      epochs: epochs,
      top: Keyword.fetch!(opts, :top),
      config: Keyword.get(opts, :config, default_config())
    }
  end

  @doc """
  A hyperchain node config, with pinner and staker private keys like a real one.
  """
  @spec default_config() :: map()
  def default_config do
    contract_id = :aeser_api_encoder.encode(:contract_pubkey, <<1::256>>)
    account_id = :aeser_api_encoder.encode(:account_pubkey, <<2::256>>)

    %{
      "chain" => %{
        "consensus" => %{
          "0" => %{
            "type" => "hyperchain",
            "config" => %{
              "child_block_time" => @block_time,
              "child_epoch_length" => 4,
              "election_contract" => contract_id,
              "staking_contract" => contract_id,
              "parent_chain" => %{
                "consensus" => %{"network_id" => "hc_parent", "type" => "AE2AE"},
                "polling" => %{
                  "nodes" => [
                    "http://parent-user:parent-password@parent-node:3013",
                    "http://other-parent-node:3013",
                    "http://parent-user:12#secret@hash-node:3013",
                    "http://parent-user:/secret@slash-node:3013",
                    "http://parent-user:12?secret@query-node:3013",
                    "parent-user:secret@bare-node:3013",
                    "http://parent-user:sec@ret@at-node:3013"
                  ]
                },
                "start_height" => 10
              },
              "pinners" => [
                %{
                  "parent_chain_account" => %{
                    "owner" => account_id,
                    "pub" => account_id,
                    "priv" => "pinner-private-key"
                  }
                }
              ],
              "stakers" => [
                %{"hyper_chain_account" => %{"pub" => account_id, "priv" => "staker-private-key"}}
              ]
            }
          }
        },
        "hard_forks" => %{"6" => 0}
      },
      "fork_management" => %{"network_id" => "hc_test"}
    }
  end

  @spec key_block_time(height()) :: non_neg_integer()
  def key_block_time(height), do: @genesis_time + height * @block_time

  @doc """
  Fakes the node with this chain until `unmock/1`, or until the calling process
  exits.
  """
  @spec mock!(t()) :: [module()]
  def mock!(sim) do
    for {module, expectations} <- fakes(sim) do
      :ok = :meck.new(module, [:passthrough])
      Enum.each(expectations, fn {name, fun} -> :ok = :meck.expect(module, name, fun) end)

      module
    end
  end

  @spec unmock([module()]) :: :ok
  def unmock(modules) do
    Enum.each(modules, fn module ->
      try do
        :meck.unload(module)
      catch
        # already restored, when the process that mocked it exited
        _kind, _reason -> :ok
      end
    end)
  end

  defp fakes(sim) do
    [
      {:aeu_env, user_config: fn path -> user_config(sim, path) end},
      {:aec_chain,
       top_height: fn -> sim.top end,
       get_key_block_by_height: fn height -> key_block(sim, height) end},
      {:aec_chain_state,
       get_key_block_hash_at_height: fn height -> key_block_hash(sim, height) end},
      {:aetx_env,
       tx_env_and_trees_from_hash: fn
         _type, <<@hash_tag, height::248>> -> {{:hc_sim_env, height}, :hc_sim_trees}
         type, hash -> :meck.passthrough([type, hash])
       end},
      {:aec_consensus_hc,
       call_consensus_contract_result: fn contract, {:hc_sim_env, height}, _trees, fun, args ->
         {:ok, contract_call(sim, height, contract, to_string(fun), args)}
       end,
       get_entropy_hash: fn epoch -> {:ok, entropy(epoch)} end}
    ]
  end

  defp user_config(%{config: config}, path) do
    if Enum.any?(@hc_config_paths, &(Enum.take(path, length(&1)) == &1)) do
      case get_in(config, path) do
        nil -> :undefined
        value -> {:ok, value}
      end
    else
      :meck.passthrough([path])
    end
  end

  defp key_block_hash(%{top: top}, height) when height >= 0 and height <= top,
    do: {:ok, <<@hash_tag, height::248>>}

  defp key_block_hash(_sim, _height), do: :error

  defp key_block(%{top: top}, height) when height >= 0 and height <= top do
    zero = <<0::256>>

    {:ok,
     :aec_blocks.new_key(
       height,
       zero,
       zero,
       zero,
       0,
       0,
       key_block_time(height),
       :default,
       6,
       zero,
       zero
     )}
  end

  defp key_block(_sim, _height), do: {:error, :chain_too_short}

  defp contract_call(sim, height, :election, fun, args) do
    %{epoch: current} = current_epoch = epoch_at(sim, height + 1)

    case {fun, args} do
      {"epoch", []} ->
        current

      {"epoch_length", []} ->
        current_epoch.length

      {"epoch_info", []} ->
        {:tuple, {current, fate_epoch_info(current_epoch)}}

      {"epoch_info_epoch", [epoch]} when epoch <= current + 1 ->
        sim |> epoch(epoch) |> fate_epoch_info()

      {"validator_schedule", [{:bytes, seed}, stakers, schedule_length]} ->
        validator_schedule(sim, seed, stakers, schedule_length)

      _other ->
        raise ArgumentError,
              "unexpected election call #{fun}(#{inspect(args)}) at height #{height}"
    end
  end

  defp contract_call(_sim, height, contract, fun, args) do
    raise ArgumentError,
          "unexpected #{contract} call #{fun}(#{inspect(args)}) at height #{height}"
  end

  defp epoch(%{epochs: epochs}, number) do
    Enum.find(epochs, &(&1.epoch == number)) || raise ArgumentError, "no epoch #{number}"
  end

  defp epoch_at(%{epochs: epochs}, height) do
    Enum.find(epochs, &(height in &1.first..&1.last)) ||
      raise ArgumentError, "no epoch at height #{height}"
  end

  # the parent chain hash an epoch takes as its seed while the chain has none
  defp entropy(epoch), do: :crypto.hash(:sha256, "parent chain entropy #{epoch}")

  defp validator_schedule(%{epochs: epochs}, seed, stakers, schedule_length) do
    case Enum.find(epochs, fn %{epoch: epoch, seed: epoch_seed} ->
           (epoch_seed || entropy(epoch)) == seed
         end) do
      %{validators: validators, length: ^schedule_length, schedule: schedule} = epoch ->
        if fate_stakers(validators) != stakers do
          raise ArgumentError, "the schedule of epoch #{epoch.epoch} takes its own stakers"
        end

        Enum.map(schedule, &{:address, &1})

      _no_epoch ->
        raise ArgumentError, "no epoch has this seed and #{schedule_length} heights"
    end
  end

  defp fate_epoch_info(%{first: first, length: epoch_length, seed: seed, validators: validators}) do
    seed_option = if seed, do: fate_some({:bytes, seed}), else: fate_none()

    {:tuple, {first, epoch_length, seed_option, fate_some(fate_stakers(validators))}}
  end

  defp fate_stakers(validators),
    do: Enum.map(validators, fn {pubkey, stake} -> {:tuple, {{:address, pubkey}, stake}} end)

  defp fate_some(value), do: {:variant, [0, 1], 1, {value}}

  defp fate_none, do: {:variant, [0, 1], 0, {}}
end
