const {Universal, Node, MemoryAccount, Crypto} = require('@aeternity/aepp-sdk')

const exampleSource = `
contract Example =
  entrypoint example(x : int) = x
`

const factorySource = `
contract Example =
  entrypoint example(x : int) = x
main contract Factory =
  stateful entrypoint create() =
    Chain.create() : Example
`

const main = async () => {
  const keypair = {
    publicKey: 'ak_4FJFaSFiTts7uStAWa7wXSHxXXrueH2f7XREykDCL21wDBxpM', // Needs to match docker/aeternity.yaml mining beneficiary
    secretKey: 'e8fc19fae94a754bcb9233b1d95d9740828a7af4ead066c3af01fcbb80202bb8075f20af877e2d8e915a4851d1791675a08e26bc91bbb88ea86eaa2384c84322'
  }

  const client = await Universal({
    compilerUrl: 'https://latest.compiler.aepps.com',
    nodes: [{
      name: 'node',
      instance: await Node({url: 'http://mdw.aeternity.localhost:3013/'}),
    }],
    accounts: [
      MemoryAccount({keypair}),
    ],
  });

  // Make sure you set
  //   config :aecore,
  //     network_id: "ae_devnet"
  // in config/config.exs before using

  // Use client here..
}

main();
