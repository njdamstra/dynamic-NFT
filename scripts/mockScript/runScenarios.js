require("dotenv").config();
const { ethers } = require("hardhat");
const { execSync } = require("child_process");
const deployedAddresses = require("./deployedAddresses.json");
const path = require("path");
const { loadWallets } = require("./loadWallets");

async function main() {
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
    const NftTrader = await ethers.getContractAt("NftTrader", deployedAddresses.NftTrader);
    const MockOracle = await ethers.getContractAt("MockOracle", deployedAddresses.MockOracle);

    // Initialize NftValues:
    /////// TODO: CHANGE BOOL TO DETERMINE IF YOU WANT TO RUN ON CHAIN (TRUE) ORACLE OR OFF CHAIN ** ///////
    const useOnChainOracle = true;
    await NftValues.initialize(deployedAddresses.CCollateralManager, useOnChainOracle, deployedAddresses.MockOracle);
    console.log("NftValues initialized.");

    /////// TODO: SET COLLECTION PRICES //////
    // IF TRUE (using on chain oracle MockOracle)
    
    const initial_GNft_FP = 10; // set initial goodNft collections floor price
    const GNft_safe = true; // set if goodNft collection is a safe collection and that borrowers can use it!
    await MockOracle.connect(deployer).manualSetCollection(deployedAddresses.GoodNft, initial_GNft_FP, GNft_safe);

    const initial_BNft_FP = 15; // set initial goodNft collections floor price
    const BNft_safe = true; // set if goodNft collection is a safe collection and that borrowers can use it!
    await MockOracle.connect(deployer).manualSetCollection(deployedAddresses.BadNft, initial_BNft_FP, BNft_safe);

    const FP_GNFT = await MockOracle.getFloorPrice(deployedAddresses.GoodNft);
    console.log("floor price returned from MockOracle should be 10: ", FP_GNFT.toString());


    ///// ** WHAT TO DO LATER **

    // Change collections FP:
    // await MockOracle.manualUpdateFloorPrice(deployedAddresses.Nft, newFloorPrice);
    
    // have MockOracle update NftValues collections:
    // await MockOracle.updateAllFloorPrices();
    
    

    // Example: Mint NFTs for borrower1 and borrower2
    console.log("Minting NFTs...");
    await GNft.connect(deployer).mint(borrower1.address);
    await GNft.connect(deployer).mint(borrower2.address);
    console.log(`Minted NFTs for borrower1 (${borrower1.address}) and borrower2 (${borrower2.address}).`);

    // Example: lender1 supplies pool with 10 ether
    const amountLending = 10; // 10 Eth in Wei

    try {
        const tx = await Portal.connect(lender2).supply(10, { value: amountLending });
        const receipt = await tx.wait();

        const poolBalance = await LendingPool.getPoolBalance();

        console.log("the lending pools balance: ", poolBalance.toString());
        console.log("Supplied successfully! Tx Hash:", receipt.transactionHash);
    } catch (error) {
        console.error("Error while supplying 10 ether from lender1:", error);
    }

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
