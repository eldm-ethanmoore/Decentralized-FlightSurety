const HDWalletProvider = require('@truffle/hdwallet-provider');
const infuraKey = "97814fdd993b4511aae0bae211c32749";
const mnemonic = "spirit supply whale amount human item harsh scare congress discover talent hamster";
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/${infuraKey}`),
        network_id: 4,       // rinkeby's id
        //gas: 4500000,        // rinkeby has a lower block limit than mainnet
        //gasPrice: 10000000000
    }
  },
  compilers: {
    solc: {
      version: "0.4.24"  // ex:  "0.4.24". (Default: Truffle's installed solc)
    }
  }
}