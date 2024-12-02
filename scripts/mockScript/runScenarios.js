require("dotenv").config();
const { ethers } = require("hardhat");
const { execSync } = require("child_process");
const deployedAddresses = require("./deployedAddresses.json");
const path = require("path");
const { loadWallets } = require("./loadWallets");

async function main() {
    // Load wallets dynamically
    const wallets = loadWallets();

    console.log("Loaded wallets:");
    Object.keys(wallets).forEach((name) => {
        console.log(`${name}: ${wallets[name].address}`);
    });

    const deployer = wallets["deployer"];
    const user1 = wallets["lender1"];
    const user2 = wallets["borrower1"];
    const liquidator = wallets["liquidator1"];

    // Load contracts
    const GoodNft = await ethers.getContractAt("GoodNFT", deployedAddresses.GoodNft);
    const NftValues = await ethers.getContractAt("NftValues", deployedAddresses.NftValues);
    const CLendingPool = await ethers.getContractAt("LendingPool", deployedAddresses.CLendingPool);

    // Scenario 1: Mint NFTs for users
    console.log("Minting NFTs...");
    await GoodNft.connect(deployer).mint(user1.address);
    await GoodNft.connect(deployer).mint(user2.address);
    console.log(`User1 now owns NFT ID 0 from GoodNft.`);
    console.log(`User2 now owns NFT ID 1 from GoodNft.`);

    // Scenario 2: Add NFT as collateral
    console.log("Adding NFT as collateral...");
    await GoodNft.connect(user1).setApprovalForAll(deployedAddresses.CCollateralManager, true);
    const collateralManager = await ethers.getContractAt("ICollateralManager", deployedAddresses.CCollateralManager);
    await collateralManager.connect(user1).provideCollateral(GoodNft.address, 0);
    console.log("User1 provided collateral with GoodNft ID 0.");

    // Scenario 3: Call mockUpdateFP.js to update prices off-chain
    console.log("Updating floor prices using mockUpdateFP.js...");
    try {
        execSync("node mockScripts/mockUpdateFP.js", { stdio: "inherit" });
        console.log("Floor prices updated successfully!");
    } catch (error) {
        console.error("Error calling mockUpdateFP.js:", error.message);
    }

    // Scenario 4: Simulate borrowing funds
    console.log("Borrowing funds...");
    const borrowAmount = ethers.parseEther("5");
    await CLendingPool.connect(user1).borrow(borrowAmount);
    console.log(`User1 borrowed ${borrowAmount} ETH.`);

    // Scenario 5: Verify updated prices in NftValues
    const updatedPrice = await NftValues.getFloorPrice(GoodNft.address); // Assuming a getFloorPrice function exists
    console.log(`Updated floor price for GoodNft ID 0: ${ethers.formatEther(updatedPrice)} ETH.`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
