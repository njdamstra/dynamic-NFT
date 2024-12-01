require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
// require("@openzeppelin/hardhat-upgrades");
// require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.27",
  networks: {
    hardhat: {
      chainId: 1337
    },
    localhost: {
      url: "http://127.0.0.1:8545" //local hardhat node
    },
    // test network??

    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY // optional for contract verification
  }
};
