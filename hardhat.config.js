require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomicfoundation/hardhat-ethers");
// require("@openzeppelin/hardhat-upgrades");
// require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.27",
  networks: {
    hardhat: {
      chainId: 1337,
      // loggingEnabled: true,
    },
    localhost: {
      url: process.env.LOCAL_NODE_URL, //local hardhat node
    },
    // test network??

    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_RPC_URL,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY // optional for contract verification
  }
};
