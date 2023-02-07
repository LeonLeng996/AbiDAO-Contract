import { HardhatUserConfig } from 'hardhat/config'
import 'hardhat-gas-reporter'
import '@nomicfoundation/hardhat-toolbox'
import '@nomiclabs/hardhat-etherscan'
import * as dotenv from 'dotenv'

dotenv.config({ path: __dirname + '/.env.local' })

const GOERLI_PRIVATE_KEY = ''
const ETHERSCAN_API_KEY = ''


const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    gasPrice: 1300,
  },
  networks: {
    localhost: {
      url: "HTTP://127.0.0.1:8545",
      chainId: 1337,
      gas: 2100000,
      gasPrice: 8000000000,
    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2",
      accounts: [GOERLI_PRIVATE_KEY],
      chainId: 5,
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
}

export default config
