require('dotenv').config();
const HDWalletProvider = require('truffle-hdwallet-provider');

var mnemonic = process.env.WALLET_MNEMONIC;

module.exports = {
  networks: {
    local: {
      host: 'localhost',
      port: 9545,
      network_id: '3',
      gas: 7400000, 
      from: process.env.ROPSTEN_FROM_ADDRESS
    },
    rinkeby: {
      host: 'localhost',
      port: 8545,
      network_id: '4',
      gas: 7400000,
      gasPrice: 10000000000,
      from: process.env.ROPSTEN_FROM_ADDRESS
    },
    mainnet_infura: {
      network_id: 1,
      gas: 7000000,
      gasPrice: 50000000000,
      provider: function() {
        return new HDWalletProvider(mnemonic, `https://mainnet.infura.io/${process.env.INFURA_API_KEY}`)
      }
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  mocha: {
    timeout: 10000,
    slow: 3000
  }
};