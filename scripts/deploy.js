const hre = require("hardhat");
const {ethers} = require("ethers");
//
// async function main() {
//   const NFTLoan = await hre.ethers.getContractFactory("NFTLoan");
//   const nftLoan = await NFTLoan.deploy();
//
//   await nftLoan.deployed();
//
//   console.log("NFTLoan deployed to:", nftLoan.address);
// }
//
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });

async function main() {
    // const NFTPricing = await ethers.getContractFactory("NFTPricing");
    // await hre.run("compile");

    // get the contract factory
    const NFTPricing = await hre.ethers.getContractFactory("NFTPricing");
    // deploy the contract
    const contract = await NFTPricing.deploy();

    // wait for the deployment contract address
    // await contract.deployed();

    console.log("NFTPricing deployed to:", contract.address); // Logs the contract address
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});

