require("dotenv").config();
const { ethers } = require("hardhat");
const deployedAddresses = require("./deployedAddresses.json");

async function main() {
    const [deployer, user1, user2, liquidator] = await ethers.getSigners();

    console.log("Running scenarios with:");
    console.log("Deployer:", deployer.address);
    console.log("User1:", user1.address);
    console.log("User2:", user2.address);
    console.log("Liquidator:", liquidator.address);

    // Load contracts
    const GoodNft = await ethers.getContractAt("GoodNft", deployedAddresses.GoodNft);
    const BadNft = await ethers.getContractAt("BadNft", deployedAddresses.BadNft);
    const NftValues = await ethers.getContractAt("NftValues", deployedAddresses.NftValues);
    const CCollateralManager = await ethers.getContractAt(
        "CCollateralManager",
        deployedAddresses.CCollateralManager
    );
    const CLendingPool = await ethers.getContractAt("CLendingPool", deployedAddresses.CLendingPool);

    // Scenario 1: Mint NFTs for users
    console.log("Minting NFTs...");
    await GoodNft.connect(deployer).mint(user1.address);
    await GoodNft.connect(deployer).mint(user2.address);
    console.log(`User1 now owns NFT ID 0 from GoodNft.`);
    console.log(`User2 now owns NFT ID 1 from GoodNft.`);

    // Scenario 2: Add NFT as collateral
    console.log("Adding NFT as collateral...");
    await GoodNft.connect(user1).setApprovalForAll(CCollateralManager.address, true);
    await CCollateralManager.connect(user1).provideCollateral(GoodNft.address, 0);
    console.log("User1 provided collateral with GoodNft ID 0.");

    // Scenario 3: Borrow funds against collateral
    console.log("Borrowing funds...");
    const borrowAmount = ethers.parseEther("5"); // User borrows 5 ETH
    await CLendingPool.connect(user1).borrow(borrowAmount);
    console.log(`User1 borrowed ${borrowAmount} ETH.`);

    // Scenario 4: Simulate a drop in collateral value
    console.log("Simulating price drop...");
    const newFloorPrice = ethers.parseEther("1"); // New price of 1 ETH
    await NftValues.connect(deployer).updateFloorPrice(GoodNft.address, 0, newFloorPrice);
    console.log("Floor price updated. Collateral value dropped.");

    // Scenario 5: Liquidation
    console.log("Attempting liquidation...");
    const healthFactor = await CCollateralManager.getHealthFactor(user1.address);
    console.log(`User1's health factor: ${healthFactor}`);
    if (healthFactor < 1) {
        await CCollateralManager.connect(liquidator).liquidate(user1.address, GoodNft.address, 0);
        console.log("Liquidation successful.");
    } else {
        console.log("User1 is still solvent. No liquidation needed.");
    }

    // Scenario 6: User2 borrows and repays
    console.log("User2 borrowing and repaying...");
    await GoodNft.connect(user2).setApprovalForAll(CCollateralManager.address, true);
    await CCollateralManager.connect(user2).provideCollateral(GoodNft.address, 1);
    console.log("User2 provided collateral with GoodNft ID 1.");

    const borrowAmount2 = ethers.parseEther("3");
    await CLendingPool.connect(user2).borrow(borrowAmount2);
    console.log(`User2 borrowed ${borrowAmount2} ETH.`);

    console.log("Repaying debt...");
    await CLendingPool.connect(user2).repay(borrowAmount2);
    console.log("User2 fully repaid the debt.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });