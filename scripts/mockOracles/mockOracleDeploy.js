require("dotenv").config();
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
const signerData = require("../mockScript/signers.json");

async function main() {
    // Load named wallets
    const wallets = signerData.reduce((acc, signer) => {
        acc[signer.name] = new ethers.Wallet(signer.privateKey, ethers.provider);
        return acc;
    }, {});

    const deployer = wallets["deployer"];

    console.log("Deploying contracts with:", deployer.address);

    const deployedAddressesPath = path.join(__dirname, "../mockScript/deployedAddresses.json");
    let deployedAddresses = {};

    // Read existing deployed addresses file, if it exists
    if (fs.existsSync(deployedAddressesPath)) {
        deployedAddresses = JSON.parse(fs.readFileSync(deployedAddressesPath, "utf8"));
    }

    // Deploy MockOracle contract
    const MockOracle = await ethers.getContractFactory("MockOracle");
    const mockOracle = await MockOracle.connect(deployer).deploy();
    const mockOracleAddr = await mockOracle.getAddress();
    deployedAddresses["MockOracle"] = mockOracleAddr;
    console.log("MockOracle deployed to:", mockOracleAddr);

    // Update deployed addresses file with new entries
    fs.writeFileSync(deployedAddressesPath, JSON.stringify(deployedAddresses, null, 2));
    console.log(`Deployed addresses updated at ${deployedAddressesPath}`);

    // Log final contract addresses
    console.log({
        deployer: deployer.address,
        MockOracle: mockOracleAddr,
    });
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
