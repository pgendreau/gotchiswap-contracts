require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    polygon_mumbai: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon: {
        url: "https://rpc.ankr.com/polygon",
        accounts: [process.env.PRIVATE_KEY]
    },
    localhost: {
      forking: {
        url: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_API_KEY}`,
        //url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      }
    },
    hardhat: {
      forking: {
        //url: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_API_KEY}`,
        url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
        //blockNumber: 46397958
      }
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY
  },
}
