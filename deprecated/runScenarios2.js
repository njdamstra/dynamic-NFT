const { ethers } = require("hardhat");
const { loadWallets } = require("../scripts/mockScript/loadWallets");
const deployedAddresses = require("../scripts/mockScript/deployedAddresses.json");
const { execSync } = require("child_process");

async function main() {
    // Load wallets dynamically
    const wallets = loadWallets();

    console.log("Loaded wallets:");
    Object.keys(wallets).forEach((name) => {
        console.log(`${name}: ${wallets[name].address}`);
    });

    const deployer = wallets["deployer"];
    const lender1 = wallets["lender1"];
    const borrower1 = wallets["borrower1"];
    const liquidator1 = wallets["liquidator1"];
    const lender2 = wallets["lender2"];
    const borrower2 = wallets["borrower2"];
    const lender3 = wallets["lender3"];
    const borrower3 = wallets["borrower3"];
    const lender4 = wallets["lender4"];
    const borrower4 = wallets["borrower4"];
    const lender5 = wallets["lender5"];
    const borrower5 = wallets["borrower5"];

    console.log("Using deployer:", deployer.address);
    console.log("Using lender1:", lender1.address);

    // Load deployed contracts
    const Portal = await ethers.getContractAt("UserPortal", deployedAddresses.UserPortal);
    const Addresses = await ethers.getContractAt("Addresses", deployedAddresses.CAddresses);
    const GNft = await ethers.getContractAt("GoodNFT", deployedAddresses.GoodNft, deployer);
    const BNft = await ethers.getContractAt("BadNFT", deployedAddresses.BadNft, deployer);
    const NftValues = await ethers.getContractAt("NftValues", deployedAddresses.NftValues);
    const LendingPool = await ethers.getContractAt("LendingPool", deployedAddresses.CLendingPool);
    const CollateralManager = await ethers.getContractAt("CollateralManager", deployedAddresses.CCollateralManager);
    const NftTrader = await ethers.getContractAt("NftTrader", deployedAddresses.NftTrader)

    // Example: Mint NFTs for lender1 and borrower1
    console.log("Minting NFTs...");
    await GNft.connect(deployer).mint(borrower1.address);
    await GNft.connect(deployer).mint(borrower2.address);
    console.log(`Minted NFTs for borrower1 (${borrower1.address}) and borrower2 (${borrower2.address}).`);

    // Example: calling oracle to update floor price
    //console.log("Updating floor prices using mockUpdateFP.js...");
    //try {
    //    execSync("node mockScripts/mockUpdateFP.js", { stdio: "inherit" });
    //    console.log("Floor prices updated successfully!");
    //} catch (error) {
    //    console.error("Error calling mockUpdateFP.js:", error.message);
    //}

    console.log("")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });