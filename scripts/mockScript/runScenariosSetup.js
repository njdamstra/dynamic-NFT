const { ethers } = require("hardhat");
const { loadWallets } = require("./loadWallets");
const deployedAddresses = require("./deployedAddresses.json");
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
    const NftTrader = await ethers.getContractAt("NftTrader", deployedAddresses.NftTrader);
    const MockOracle = await ethers.getContractAt("MockOracle", deployedAddresses.MockOracle);

    // Initialize NftValues:
    /////// TODO: CHANGE BOOL TO DETERMINE IF YOU WANT TO RUN ON CHAIN (TRUE) ORACLE OR OFF CHAIN ** ///////
    const useOnChainOracle = true;
    await NftValues.initialize(CMAddr, useOnChainOracle, deployedAddresses.MockOracle);
    console.log("NftValues initialized.");

    /////// TODO: SET COLLECTION PRICES //////
    // IF TRUE (using on chain oracle MockOracle)
    if (useOnChainOracle) {
        const initial_GNft_FP = 10; // set initial goodNft collections floor price
        const GNft_safe = true; // set if goodNft collection is a safe collection and that borrowers can use it!
        await MockOracle.manualSetCollection(deployedAddresses.GoodNft, initial_GNft_FP, GNft_safe);

        const initial_BNft_FP = 10; // set initial goodNft collections floor price
        const BNft_safe = true; // set if goodNft collection is a safe collection and that borrowers can use it!
        await MockOracle.manualSetCollection(deployedAddresses.BadNft, initial_BNft_FP, BNft_safe);

        ///// ** WHAT TO DO LATER **

        // Change collections FP:
        // await MockOracle.manualUpdateFloorPrice(deployedAddresses.Nft, newFloorPrice);
        
        // have MockOracle update NftValues collections:
        // await MockOracle.updateAllFloorPrices();
    // IF FALSE (using off chain oracle (real world))
    } else if (!useOnChainOracle) {
        // 1) go to mockRequestFP.js and update safety of the collection and initial FP
        // 2) go to mockUpdateFP.js and change the FP that'll be iterated through one by one everytime you call:
        // console.log("Updating floor prices using mockUpdateFP.js...");
        // try {
        //     execSync("node mockScripts/mockUpdateFP.js", { stdio: "inherit" });
        //     console.log("Floor prices updated successfully!");
        // } catch (error) {
        //     console.error("Error calling mockUpdateFP.js:", error.message);
    }
    

    // Example: Mint NFTs for lender1 and borrower1
    console.log("Minting NFTs...");
    await GNft.connect(deployer).mint(borrower1.address);
    await GNft.connect(deployer).mint(borrower2.address);
    console.log(`Minted NFTs for borrower1 (${borrower1.address}) and borrower2 (${borrower2.address}).`);

    // Example: calling oracle to update floor price
    console.log("Updating floor prices using mockUpdateFP.js...");
    try {
        execSync("node mockScripts/mockUpdateFP.js", { stdio: "inherit" });
        console.log("Floor prices updated successfully!");
    } catch (error) {
        console.error("Error calling mockUpdateFP.js:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });