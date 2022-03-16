import '@nomiclabs/hardhat-waffle';
import 'dotenv/config';

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    rinkeby: {
      url: process.env.RINKEBY_URL,
      accounts: [process.env.PRIVATE_KEY],
      allowUnlimitedContractSize: true,
    },
    velas: {
      url: process.env.VELASCAN_URL,
      accounts: [process.env.REAL],
      allowUnlimitedContractSize: true,
    },
  },
  solidity: {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 40000,
  },
};

// export default {
//   solidity: '0.8.4',
// };
