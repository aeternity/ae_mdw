defmodule AeMdw.TestSamples do
  require AeMdw.Db.Model

  alias AeMdw.Db.Model

  @spec oracle_expiration_key(non_neg_integer()) :: binary()
  def oracle_expiration_key(n) do
    ~w(
      ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR
      ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM
      ok_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT
      ok_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf
      ok_cnFq6NgPNXzcwtggcAYUuSNKrW6fhRfDgYJa9WoRe6mEXwpah
    )
    |> Enum.with_index()
    |> Enum.map(fn {key, index} ->
      {:ok, pk} = :aeser_api_encoder.safe_decode(:oracle_pubkey, key)

      {expire_height(index), pk}
    end)
    |> Enum.at(n)
  end

  @spec plain_name(non_neg_integer()) :: binary()
  def plain_name(n) do
    ~w(aaaaa.chain bbbbb.chain ccccc.chain dddddd.chain eeeeee.chain)
    |> Enum.at(n)
  end

  @spec name_expiration_key(non_neg_integer()) :: {non_neg_integer(), binary()}
  def name_expiration_key(n) do
    ~w(aaaaa.chain bbbbb.chain ccccc.chain dddddd.chain eeeeee.chain)
    |> Enum.with_index()
    |> Enum.map(fn {plain_name, index} -> {expire_height(index), plain_name} end)
    |> Enum.at(n)
  end

  @spec expire_height(non_neg_integer()) :: non_neg_integer()
  def expire_height(n) do
    ~w(5851 6894 7499 34919 35040) |> Enum.at(n) |> String.to_integer()
  end

  @spec last_gen() :: {non_neg_integer(), -1}
  def last_gen do
    {484_402, -1}
  end

  @spec oracle() :: Model.oracle()
  def oracle do
    {:oracle,
     <<191, 26, 12, 186, 4, 218, 249, 80, 53, 193, 143, 183, 72, 192, 245, 70, 194, 128, 17, 36,
       177, 223, 218, 73, 7, 139, 204, 31, 194, 87, 254, 212>>, 4608, 5851, {{4608, 0}, 8916},
     [{{4609, 0}, 8989}], nil}
  end

  @spec core_oracle() :: :aeo_oracles.oracle()
  def core_oracle do
    {:oracle,
     {:id, :oracle,
      <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24, 251,
        165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>}, "querySpace", "responseSpec",
     2_000_000_000_000_000, 288_692, 0}
  end

  @spec tx_hash(non_neg_integer()) :: Txs.tx_hash()
  def tx_hash(n) do
    ~w(
      th_2MMJRvBUj69PHoZhQtrrXHAg5iXCVwPcunXrKaPcVB6yhAuUHo
      th_uJ5os7Gg8P68SHTq1kYecNzjNPFp3exxhXvqWmpFfsS7mbKSG
      th_2CdVYuqtpcjoshDw2otjbLEyj8SpxjMP9MCgpn1oU9zGaqvUn4
      th_2oBM2J4CtvXyg3ZNKdwbhskjQXTGn6AHA8iZqiYB2YEZjbjPP1
      th_2gyafjpuMFK16ZcJjp4ss5GtENJYZjBtgMxc5E6xguaT2TqHpy
    )
    |> Enum.map(fn tx_hash ->
      {:ok, hash} = :aeser_api_encoder.safe_decode(:tx_hash, tx_hash)

      hash
    end)
    |> Enum.at(n)
  end

  @spec tx(non_neg_integer()) :: Model.tx()
  def tx(n) do
    Model.tx(index: n * 200, id: tx_hash(n))
  end

  @spec key_block_hash(non_neg_integer()) :: Blocks.block_hash()
  def key_block_hash(n) do
    ~w(
      kh_2f4aqtJjJpNdgYMsvXJ8E8XECNSJPfkj3B482yfZ5wAXN6aJAT
      kh_2gfAhphwc1nqdqmpmzewqKDNkwfgBDrF2zJ7PBzt2nujjBevHg
      kh_EQvXNAZLUtA98FeSUKjwuusuoMvHBPUMAJ4rDBuRBs5mWbvxs
      kh_p5Ah5sKuGd3B4Z6Md4wwXvv1C4DBuNEWovraEVefbyCTtYUfU
    )
    |> Enum.map(fn hash ->
      {:ok, decoded_hash} = :aeser_api_encoder.safe_decode(:key_block_hash, hash)

      decoded_hash
    end)
    |> Enum.at(n)
  end

  @spec micro_block_hash(non_neg_integer()) :: Blocks.block_hash()
  def micro_block_hash(n) do
    ~w(
      mh_g9g4iz96sofJD55MAiyQJcUfgRh69euZ22iNCas79ZF3N8tEZ
      mh_2Zg4FUabugLuvKa9dSaWMzmCsQojsckE9tSmLbnjobH52XUQ1r
      mh_uzKFFWu1jNmsarwWTk79uLENB6Wac8fZg6eWzm68GzN4LaocW
    )
    |> Enum.map(fn hash ->
      {:ok, decoded_hash} = :aeser_api_encoder.safe_decode(:micro_block_hash, hash)

      decoded_hash
    end)
    |> Enum.at(n)
  end

  @spec address(non_neg_integer()) :: Db.pubkey()
  def address(n) do
    ~w(
      ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs
      ak_2ZJdpRWp6AdbjbuDtYjzAB7BXM4N7kz1novbK4qKH4XW6W3GrZ
      ak_VS3fcBcwyo3dMEFXUJk91J4fhaDUE7bU5NDaDVDghjB7wVN1t
      ak_6sssiKcg7AywyJkfSdHz52RbDUq5cZe4V4hcvghXnrPz4H4Qg
      ak_2jxip8MNK2gHJFUD1ozLyEp4ieC3hL1VYsCcsnVPxnek9AuQc8
    )
    |> Enum.map(fn hash ->
      {:ok, decoded_hash} = :aeser_api_encoder.safe_decode(:account_pubkey, hash)

      decoded_hash
    end)
    |> Enum.at(n)
  end

  @spec contract_pk(non_neg_integer()) :: Db.pubkey()
  def contract_pk(n) do
    ~w(
      ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo
      ct_azbNZ1XrPjXfqBqbAh1ffLNTQ1sbnuUDFvJrXjYz7JQA1saQ3
      ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6
      ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z
      ct_jmRkfpzmn7KZbXbkEL9wueJkb1vaFzMnVFJMFjAnJgj1CTtQe
    )
    |> Enum.map(fn hash ->
      {:ok, decoded_hash} = :aeser_api_encoder.safe_decode(:contract_pubkey, hash)

      decoded_hash
    end)
    |> Enum.at(n)
  end

  @spec channel_pk(non_neg_integer()) :: Db.pubkey()
  def channel_pk(n) do
    ~w(
      ch_22SfHdnhUQBAHpC5euxHG9qjRWGfHsj47sZqSmXk4cTfJp4aUd
      ch_vpYXyMJZDF8Rdc3EZFvLdKYrWZKsbs1hKXHXMAczeV8MmDPkK
      ch_hhqtLjXn9h31Sa6WTNxTANC1zG3WxUzCss1HnJSjovP4pnVUK
    )
    |> Enum.map(fn hash ->
      {:ok, decoded_hash} = :aeser_api_encoder.safe_decode(:channel, hash)

      decoded_hash
    end)
    |> Enum.at(n)
  end
end
