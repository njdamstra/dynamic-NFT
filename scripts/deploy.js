const hre = require("hardhat");
const {ethers} = require("ethers");


async function main() {

    // get the contract factory
    const NFTPricing = await hre.ethers.getContractFactory("NFTPricing");
    // deploy the contract
    const contract = await NFTPricing.deploy();
    // Wait for the transaction to be mined
    // const deploymentReceipt = await contract.deploymentTransaction().wait();
    // console.log("Deployment transaction mined:", deploymentReceipt.transactionHash);

    // get and log the contract address:
    const contractAddress = await contract.getAddress();
    console.log("NFTPricing deployed to:", contractAddress); // Logs the contract address

    const deployer = (await hre.ethers.getSigners())[0];
    console.log("Deployer address:", deployer.address);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});

