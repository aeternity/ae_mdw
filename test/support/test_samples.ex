defmodule AeMdw.TestSamples do
  @moduledoc false

  alias AeMdw.Oracles
  alias AeMdw.Db.Model

  require Model

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
    Model.oracle(
      index:
        <<191, 26, 12, 186, 4, 218, 249, 80, 53, 193, 143, 183, 72, 192, 245, 70, 194, 128, 17,
          36, 177, 223, 218, 73, 7, 139, 204, 31, 194, 87, 254, 212>>,
      active: 4608,
      expire: 5851,
      register: {{4608, 0}, {8916, -1}},
      extends: [{{4609, 0}, {8989, -1}}],
      previous: nil
    )
  end

  @spec core_oracle() :: :aeo_oracles.oracle()
  def core_oracle do
    {:oracle,
     {:id, :oracle,
      <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24, 251,
        165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>}, "querySpace", "responseSpec",
     2_000_000_000_000_000, 288_692, 0}
  end

  @spec oracle_pk(non_neg_integer()) :: Db.pubkey()
  def oracle_pk(n) do
    ~w(
      ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR
      ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM
      ok_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT
      ok_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf
      ok_cnFq6NgPNXzcwtggcAYUuSNKrW6fhRfDgYJa9WoRe6mEXwpah
    )
    |> Enum.map(fn tx_hash ->
      {:ok, hash} = :aeser_api_encoder.safe_decode(:oracle_pubkey, tx_hash)

      hash
    end)
    |> Enum.at(n)
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
    Model.tx(
      index: n * 200,
      id: tx_hash(n),
      block_index: {0, 0},
      time: DateTime.utc_now() |> DateTime.to_unix()
    )
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

  @spec oracle_query_id(non_neg_integer()) :: Oracles.query_id()
  def oracle_query_id(n) do
    oracle_pk = oracle_pk(0)
    sender_pk = address(0)

    :aeo_query.id(sender_pk, n, oracle_pk)
  end

  @spec pending_txs() :: [Model.mempool()]
  def pending_txs do
    keys =
      [
        {-16_540_000_000_000, 0,
         <<220, 197, 41, 128, 121, 27, 156, 252, 77, 242, 55, 250, 125, 53, 22, 21, 37, 221, 142,
           73, 236, 230, 51, 211, 5, 2, 1, 101, 38, 167, 202, 28>>, 2,
         <<72, 210, 141, 245, 218, 177, 236, 114, 205, 23, 209, 228, 114, 102, 174, 229, 109, 225,
           78, 52, 211, 238, 225, 24, 41, 189, 206, 176, 198, 1, 250, 30>>},
        {-16_820_000_000_000, 0,
         <<162, 81, 250, 43, 65, 194, 206, 31, 0, 196, 58, 150, 38, 183, 86, 98, 215, 159, 202,
           93, 97, 57, 236, 243, 160, 101, 160, 112, 72, 64, 206, 69>>, 1,
         <<126, 250, 144, 26, 65, 65, 234, 22, 59, 92, 123, 254, 38, 34, 44, 236, 190, 109, 78,
           17, 164, 206, 19, 83, 92, 10, 25, 117, 158, 234, 53, 141>>},
        {-16_820_000_000_000, 0,
         <<162, 81, 250, 43, 65, 194, 206, 31, 0, 196, 58, 150, 38, 183, 86, 98, 215, 159, 202,
           93, 97, 57, 236, 243, 160, 101, 160, 112, 72, 64, 206, 69>>, 1,
         <<85, 110, 178, 163, 64, 210, 113, 50, 120, 186, 195, 201, 141, 120, 118, 180, 134, 154,
           166, 85, 15, 12, 46, 92, 182, 70, 175, 90, 163, 229, 209, 48>>},
        {-16_820_000_000_000, 0,
         <<53, 77, 0, 158, 42, 235, 17, 232, 74, 198, 238, 132, 89, 95, 153, 112, 220, 4, 71, 211,
           172, 156, 234, 62, 17, 239, 26, 14, 236, 209, 46, 117>>, 1,
         <<183, 65, 158, 172, 69, 252, 189, 90, 95, 253, 152, 213, 135, 121, 45, 38, 192, 102, 37,
           170, 249, 177, 24, 174, 235, 209, 229, 38, 168, 80, 109, 84>>},
        {-16_820_000_000_000, 0,
         <<53, 77, 0, 158, 42, 235, 17, 232, 74, 198, 238, 132, 89, 95, 153, 112, 220, 4, 71, 211,
           172, 156, 234, 62, 17, 239, 26, 14, 236, 209, 46, 117>>, 1,
         <<125, 123, 87, 103, 126, 175, 120, 90, 236, 103, 44, 91, 167, 13, 84, 26, 94, 124, 75,
           127, 120, 204, 64, 53, 32, 130, 45, 15, 220, 210, 227, 139>>},
        {-16_840_000_000_000, 0,
         <<149, 159, 182, 188, 76, 104, 42, 30, 189, 44, 203, 222, 100, 99, 202, 204, 253, 83,
           170, 58, 103, 250, 231, 58, 219, 54, 142, 30, 169, 102, 86, 140>>, 4,
         <<91, 235, 144, 157, 223, 208, 12, 205, 73, 121, 70, 187, 11, 236, 222, 214, 152, 73,
           206, 23, 163, 151, 188, 157, 66, 139, 228, 237, 149, 161, 12, 46>>},
        {-16_840_000_000_000, 0,
         <<117, 18, 229, 241, 46, 49, 48, 163, 139, 221, 116, 34, 42, 221, 16, 36, 178, 20, 166,
           104, 107, 227, 150, 226, 60, 128, 219, 68, 35, 194, 199, 244>>, 4,
         <<124, 123, 215, 212, 136, 52, 32, 57, 175, 83, 21, 56, 223, 210, 205, 188, 63, 231, 105,
           31, 198, 246, 79, 167, 42, 10, 86, 17, 157, 170, 11, 229>>},
        {-16_840_000_000_000, 0,
         <<117, 18, 229, 241, 46, 49, 48, 163, 139, 221, 116, 34, 42, 221, 16, 36, 178, 20, 166,
           104, 107, 227, 150, 226, 60, 128, 219, 68, 35, 194, 199, 244>>, 3,
         <<226, 41, 113, 118, 233, 94, 2, 44, 128, 137, 20, 52, 140, 162, 194, 5, 108, 150, 31,
           83, 123, 174, 118, 135, 95, 73, 57, 133, 44, 207, 197, 94>>},
        {-16_840_000_000_000, 0,
         <<108, 36, 23, 211, 2, 34, 209, 61, 102, 110, 247, 175, 243, 182, 131, 166, 207, 88, 246,
           94, 93, 32, 37, 235, 214, 110, 10, 214, 44, 25, 129, 12>>, 93,
         <<48, 46, 119, 76, 34, 231, 144, 212, 64, 49, 125, 107, 31, 147, 234, 138, 108, 46, 50,
           199, 90, 108, 84, 36, 177, 8, 44, 110, 238, 9, 216, 64>>},
        {-19_300_000_000_000, 0,
         <<123, 165, 128, 147, 131, 246, 100, 117, 15, 97, 130, 34, 168, 78, 88, 42, 65, 254, 96,
           207, 243, 24, 178, 217, 137, 8, 51, 36, 193, 197, 115, 214>>, 12_520_935,
         <<171, 13, 8, 122, 46, 167, 115, 206, 254, 172, 161, 11, 59, 62, 105, 166, 81, 198, 23,
           219, 248, 73, 105, 5, 25, 228, 134, 123, 104, 238, 195, 75>>}
      ]

    values = [
      {:tx,
       <<72, 210, 141, 245, 218, 177, 236, 114, 205, 23, 209, 228, 114, 102, 174, 229, 109, 225,
         78, 52, 211, 238, 225, 24, 41, 189, 206, 176, 198, 1, 250, 30>>,
       {:signed_tx,
        {:aetx, :name_claim_tx, :aens_claim_tx, 77,
         {:ns_claim_tx,
          {:id, :account,
           <<220, 197, 41, 128, 121, 27, 156, 252, 77, 242, 55, 250, 125, 53, 22, 21, 37, 221,
             142, 73, 236, 230, 51, 211, 5, 2, 1, 101, 38, 167, 202, 28>>}, 2, "Satyr.chain",
          7_219_774_424_721_251, 83_204_000_000_000_000_000, 16_540_000_000_000, 0}},
        [
          <<113, 7, 33, 67, 128, 194, 180, 99, 175, 179, 68, 65, 231, 110, 230, 178, 98, 127, 22,
            198, 236, 41, 106, 204, 8, 63, 93, 164, 10, 50, 127, 210, 8, 92, 172, 185, 58, 238,
            124, 44, 169, 22, 151, 4, 172, 125, 224, 23, 194, 158, 240, 20, 76, 22, 17, 191, 47,
            167, 50, 131, 198, 67, 74, 1>>
        ]}, 0},
      {:tx,
       <<104, 44, 53, 191, 43, 47, 4, 186, 69, 228, 147, 100, 51, 246, 77, 95, 73, 22, 181, 103,
         228, 183, 198, 189, 60, 178, 186, 72, 119, 160, 45, 191>>,
       {:signed_tx,
        {:aetx, :name_claim_tx, :aens_claim_tx, 83,
         {:ns_claim_tx,
          {:id, :account,
           <<227, 137, 173, 239, 59, 61, 148, 18, 68, 238, 60, 211, 234, 144, 236, 151, 94, 113,
             171, 242, 71, 44, 43, 220, 56, 92, 229, 192, 66, 237, 4, 149>>}, 105,
          "BlockEra.chain", 5_103_455_439_679_490, 19_641_800_000_000_000_000, 16_660_000_000_000,
          1_019_916}},
        [
          <<149, 182, 119, 3, 89, 50, 182, 130, 122, 233, 151, 106, 44, 28, 99, 121, 240, 230,
            125, 19, 240, 161, 208, 139, 88, 133, 139, 177, 13, 24, 231, 16, 228, 46, 72, 253, 72,
            26, 49, 85, 225, 46, 233, 31, 115, 44, 103, 74, 76, 161, 141, 131, 67, 234, 193, 109,
            244, 134, 40, 39, 78, 82, 75, 9>>
        ]}, 0},
      {:tx,
       <<126, 250, 144, 26, 65, 65, 234, 22, 59, 92, 123, 254, 38, 34, 44, 236, 190, 109, 78, 17,
         164, 206, 19, 83, 92, 10, 25, 117, 158, 234, 53, 141>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 91,
         {:spend_tx,
          {:id, :account,
           <<162, 81, 250, 43, 65, 194, 206, 31, 0, 196, 58, 150, 38, 183, 86, 98, 215, 159, 202,
             93, 97, 57, 236, 243, 160, 101, 160, 112, 72, 64, 206, 69>>},
          {:id, :account,
           <<52, 222, 16, 47, 94, 172, 104, 34, 117, 55, 70, 142, 57, 211, 28, 182, 103, 170, 182,
             60, 150, 27, 84, 194, 13, 7, 60, 144, 30, 202, 158, 66>>}, 1_000_000_000_000_000_000,
          16_820_000_000_000, 0, 1, ""}},
        [
          <<222, 66, 7, 25, 132, 211, 236, 3, 232, 113, 207, 72, 83, 107, 105, 231, 244, 249, 24,
            12, 45, 118, 22, 188, 32, 75, 205, 24, 81, 72, 166, 231, 115, 226, 157, 65, 163, 93,
            121, 98, 192, 3, 56, 180, 156, 37, 253, 178, 133, 126, 94, 209, 70, 81, 143, 135, 67,
            93, 187, 13, 120, 27, 175, 13>>
        ]}, 0},
      {:tx,
       <<85, 110, 178, 163, 64, 210, 113, 50, 120, 186, 195, 201, 141, 120, 118, 180, 134, 154,
         166, 85, 15, 12, 46, 92, 182, 70, 175, 90, 163, 229, 209, 48>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 91,
         {:spend_tx,
          {:id, :account,
           <<162, 81, 250, 43, 65, 194, 206, 31, 0, 196, 58, 150, 38, 183, 86, 98, 215, 159, 202,
             93, 97, 57, 236, 243, 160, 101, 160, 112, 72, 64, 206, 69>>},
          {:id, :account,
           <<222, 179, 239, 225, 27, 135, 108, 182, 163, 50, 161, 13, 60, 28, 6, 147, 57, 216, 20,
             106, 87, 9, 216, 200, 139, 96, 107, 225, 160, 177, 229, 158>>},
          1_000_000_000_000_000_000, 16_820_000_000_000, 0, 1, ""}},
        [
          <<161, 78, 174, 171, 194, 230, 240, 202, 189, 66, 151, 32, 184, 77, 234, 177, 156, 98,
            141, 172, 29, 196, 237, 217, 251, 247, 101, 215, 221, 25, 248, 224, 54, 234, 128, 112,
            13, 148, 75, 106, 2, 208, 106, 141, 109, 128, 191, 152, 64, 218, 73, 9, 27, 62, 160,
            212, 253, 192, 154, 121, 252, 11, 155, 14>>
        ]}, 0},
      {:tx,
       <<183, 65, 158, 172, 69, 252, 189, 90, 95, 253, 152, 213, 135, 121, 45, 38, 192, 102, 37,
         170, 249, 177, 24, 174, 235, 209, 229, 38, 168, 80, 109, 84>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 91,
         {:spend_tx,
          {:id, :account,
           <<53, 77, 0, 158, 42, 235, 17, 232, 74, 198, 238, 132, 89, 95, 153, 112, 220, 4, 71,
             211, 172, 156, 234, 62, 17, 239, 26, 14, 236, 209, 46, 117>>},
          {:id, :account,
           <<54, 77, 250, 95, 122, 136, 84, 76, 59, 236, 5, 221, 182, 89, 56, 196, 174, 196, 80,
             12, 2, 35, 100, 19, 231, 173, 175, 72, 229, 200, 175, 223>>},
          1_000_000_000_000_000_000, 16_820_000_000_000, 0, 1, ""}},
        [
          <<29, 95, 80, 51, 238, 66, 164, 10, 225, 74, 170, 229, 165, 94, 108, 110, 237, 214, 82,
            145, 125, 82, 188, 14, 195, 12, 148, 43, 110, 121, 233, 178, 196, 251, 232, 142, 35,
            197, 5, 177, 37, 1, 45, 142, 185, 77, 104, 94, 52, 42, 73, 180, 228, 220, 50, 177,
            105, 55, 255, 26, 163, 65, 98, 12>>
        ]}, 0},
      {:tx,
       <<125, 123, 87, 103, 126, 175, 120, 90, 236, 103, 44, 91, 167, 13, 84, 26, 94, 124, 75,
         127, 120, 204, 64, 53, 32, 130, 45, 15, 220, 210, 227, 139>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 91,
         {:spend_tx,
          {:id, :account,
           <<53, 77, 0, 158, 42, 235, 17, 232, 74, 198, 238, 132, 89, 95, 153, 112, 220, 4, 71,
             211, 172, 156, 234, 62, 17, 239, 26, 14, 236, 209, 46, 117>>},
          {:id, :account,
           <<205, 24, 41, 242, 175, 160, 37, 207, 164, 71, 183, 85, 240, 199, 17, 84, 117, 251,
             173, 84, 214, 174, 2, 26, 192, 209, 255, 36, 174, 214, 230, 89>>},
          1_000_000_000_000_000_000, 16_820_000_000_000, 0, 1, ""}},
        [
          <<183, 21, 174, 84, 20, 56, 21, 240, 176, 131, 34, 9, 5, 24, 4, 114, 127, 171, 184, 31,
            64, 80, 226, 116, 233, 27, 213, 219, 26, 23, 79, 119, 179, 181, 222, 237, 180, 206,
            212, 113, 202, 61, 98, 29, 96, 167, 75, 181, 203, 130, 33, 137, 182, 124, 74, 103,
            133, 253, 247, 221, 50, 3, 40, 9>>
        ]}, 0},
      {:tx,
       <<91, 235, 144, 157, 223, 208, 12, 205, 73, 121, 70, 187, 11, 236, 222, 214, 152, 73, 206,
         23, 163, 151, 188, 157, 66, 139, 228, 237, 149, 161, 12, 46>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 92,
         {:spend_tx,
          {:id, :account,
           <<149, 159, 182, 188, 76, 104, 42, 30, 189, 44, 203, 222, 100, 99, 202, 204, 253, 83,
             170, 58, 103, 250, 231, 58, 219, 54, 142, 30, 169, 102, 86, 140>>},
          {:id, :account,
           <<26, 222, 33, 223, 113, 87, 32, 157, 132, 154, 91, 161, 158, 111, 91, 59, 72, 108, 30,
             249, 226, 38, 162, 166, 105, 44, 86, 150, 130, 122, 26, 34>>},
          70_000_000_000_000_000_000, 16_840_000_000_000, 0, 4, ""}},
        [
          <<113, 158, 102, 187, 160, 242, 172, 56, 198, 245, 210, 193, 117, 207, 97, 220, 138,
            165, 31, 177, 71, 216, 219, 104, 238, 229, 79, 92, 110, 111, 106, 64, 129, 149, 249,
            105, 34, 36, 19, 137, 193, 71, 83, 116, 125, 173, 220, 4, 37, 15, 227, 147, 10, 142,
            85, 216, 100, 0, 122, 40, 138, 208, 43, 14>>
        ]}, 0},
      {:tx,
       <<124, 123, 215, 212, 136, 52, 32, 57, 175, 83, 21, 56, 223, 210, 205, 188, 63, 231, 105,
         31, 198, 246, 79, 167, 42, 10, 86, 17, 157, 170, 11, 229>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 92,
         {:spend_tx,
          {:id, :account,
           <<117, 18, 229, 241, 46, 49, 48, 163, 139, 221, 116, 34, 42, 221, 16, 36, 178, 20, 166,
             104, 107, 227, 150, 226, 60, 128, 219, 68, 35, 194, 199, 244>>},
          {:id, :account,
           <<52, 46, 32, 50, 213, 128, 6, 93, 18, 153, 42, 186, 114, 113, 75, 117, 194, 199, 237,
             110, 63, 79, 11, 58, 172, 203, 196, 90, 128, 186, 66, 224>>},
          1_228_888_918_596_175_475_000, 16_840_000_000_000, 0, 4, ""}},
        [
          <<86, 178, 15, 101, 105, 55, 39, 220, 200, 215, 37, 190, 144, 39, 107, 88, 53, 202, 92,
            11, 79, 16, 210, 47, 16, 0, 48, 66, 196, 50, 158, 191, 175, 201, 180, 2, 164, 23, 231,
            188, 117, 14, 210, 180, 63, 48, 153, 225, 234, 181, 53, 98, 147, 240, 58, 115, 86, 5,
            130, 83, 84, 3, 255, 0>>
        ]}, 0},
      {:tx,
       <<226, 41, 113, 118, 233, 94, 2, 44, 128, 137, 20, 52, 140, 162, 194, 5, 108, 150, 31, 83,
         123, 174, 118, 135, 95, 73, 57, 133, 44, 207, 197, 94>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 92,
         {:spend_tx,
          {:id, :account,
           <<117, 18, 229, 241, 46, 49, 48, 163, 139, 221, 116, 34, 42, 221, 16, 36, 178, 20, 166,
             104, 107, 227, 150, 226, 60, 128, 219, 68, 35, 194, 199, 244>>},
          {:id, :account,
           <<52, 46, 32, 50, 213, 128, 6, 93, 18, 153, 42, 186, 114, 113, 75, 117, 194, 199, 237,
             110, 63, 79, 11, 58, 172, 203, 196, 90, 128, 186, 66, 224>>},
          1_228_888_918_596_175_475_000, 16_840_000_000_000, 0, 3, ""}},
        [
          <<226, 186, 93, 94, 51, 74, 223, 224, 114, 228, 70, 161, 180, 250, 232, 164, 84, 90,
            251, 105, 12, 77, 20, 91, 14, 95, 5, 17, 161, 215, 2, 12, 89, 188, 32, 42, 89, 65,
            231, 95, 142, 68, 197, 154, 232, 7, 195, 67, 10, 225, 60, 180, 252, 99, 144, 101, 159,
            181, 90, 168, 84, 227, 40, 0>>
        ]}, 0},
      {:tx,
       <<171, 13, 8, 122, 46, 167, 115, 206, 254, 172, 161, 11, 59, 62, 105, 166, 81, 198, 23,
         219, 248, 73, 105, 5, 25, 228, 134, 123, 104, 238, 195, 75>>,
       {:signed_tx,
        {:aetx, :spend_tx, :aec_spend_tx, 215,
         {:spend_tx,
          {:id, :account,
           <<123, 165, 128, 147, 131, 246, 100, 117, 15, 97, 130, 34, 168, 78, 88, 42, 65, 254,
             96, 207, 243, 24, 178, 217, 137, 8, 51, 36, 193, 197, 115, 214>>},
          {:id, :account,
           <<123, 165, 128, 147, 131, 246, 100, 117, 15, 97, 130, 34, 168, 78, 88, 42, 65, 254,
             96, 207, 243, 24, 178, 217, 137, 8, 51, 36, 193, 197, 115, 214>>}, 20_000,
          19_300_000_000_000, 912_851, 12_520_935,
          "912841:kh_DNdXiqHkn3XZJNZaibKi2gDUd6LqoeKRAhgrhTBvWhpmguov2:mh_jJwmmAqr6HLEKTo1D9Huo2Byv3Su4uQW1Hve8K9Xm3KJENJjM:1709831021"}},
        [
          <<183, 237, 153, 85, 235, 39, 214, 188, 85, 248, 224, 189, 172, 20, 252, 161, 24, 97,
            233, 101, 87, 162, 152, 220, 4, 88, 87, 38, 138, 210, 19, 17, 133, 13, 120, 94, 4,
            206, 195, 98, 134, 165, 63, 44, 223, 57, 168, 111, 86, 126, 131, 247, 51, 192, 24,
            204, 145, 117, 158, 46, 14, 19, 21, 13>>
        ]}, 0}
    ]

    keys
    |> Enum.zip(values)
    |> Enum.map(fn {key, value} -> Model.mempool(index: key, tx: value) end)
  end
end
