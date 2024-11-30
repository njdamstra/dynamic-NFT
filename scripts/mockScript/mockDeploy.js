require("dotenv").config();
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with:", deployer.address);

    // Deploy GoodNft (Mock NFT contract)
    const GoodNft = await ethers.getContractFactory("GoodNft");
    const goodNft = await GoodNft.deploy();
    await goodNft.deployed();
    console.log("GoodNft deployed to:", goodNft.address);

    // Deploy BadNft (Mock NFT contract)
    const BadNft = await ethers.getContractFactory("BadNft");
    const badNft = await BadNft.deploy();
    await badNft.deployed();
    console.log("BadNft deployed to:", badNft.address);

    // Deploy CAddresses
    const CAddresses = await ethers.getContractFactory("CAddresses");
    const cAddresses = await CAddresses.deploy();
    await cAddresses.deployed();
    console.log("CAddresses deployed to:", cAddresses.address);

    // Deploy CLendingPool
    const CLendingPool = await ethers.getContractFactory("CLendingPool");
    const cLendingPool = await CLendingPool.deploy();
    await cLendingPool.deployed();
    console.log("CLendingPool deployed to:", cLendingPool.address);

    // Deploy CCollateralManager
    const CCollateralManager = await ethers.getContractFactory("CCollateralManager");
    const cCollateralManager = await CCollateralManager.deploy();
    await cCollateralManager.deployed();
    console.log("CCollateralManager deployed to:", cCollateralManager.address);

    // Deploy NftTrader
    const NftTrader = await ethers.getContractFactory("NftTrader");
    const nftTrader = await NftTrader.deploy();
    await nftTrader.deployed();
    console.log("NftTrader deployed to:", nftTrader.address);

    // Deploy NftValues
    const NftValues = await ethers.getContractFactory("NftValues");
    const nftValues = await NftValues.deploy();
    await nftValues.deployed();
    console.log("NftValues deployed to:", nftValues.address);

    // Initialize contracts
    console.log("Initializing contracts...");

    // Initialize NftValues
    await nftValues.initialize(cCollateralManager.address);
    console.log("NftValues initialized.");

    // Initialize CCollateralManager
    await cCollateralManager.initialize(
        cLendingPool.address,
        nftTrader.address,
        nftValues.address
    );
    console.log("CCollateralManager initialized.");

    // Initialize NftTrader
    await nftTrader.initialize(cCollateralManager.address, cLendingPool.address);
    console.log("NftTrader initialized.");

    // Initialize CLendingPool
    const lpTokenAddr = "0xMockLpTokenAddress"; // Replace with actual LPToken contract address if available
    const dbTokenAddr = "0xMockDbTokenAddress"; // Replace with actual DBToken contract address if available
    await cLendingPool.initialize(lpTokenAddr, dbTokenAddr, cCollateralManager.address);
    console.log("CLendingPool initialized.");

    // Initialize CAddresses with contract addresses
    await cAddresses.setAddress("GoodNft", goodNft.address);
    await cAddresses.setAddress("BadNft", badNft.address);
    await cAddresses.setAddress("CAddresses", cAddresses.address);
    await cAddresses.setAddress("NftValues", nftValues.address);
    await cAddresses.setAddress("CCollateralManager", cCollateralManager.address);
    await cAddresses.setAddress("NftTrader", nftTrader.address);
    await cAddresses.setAddress("CLendingPool", cLendingPool.address);

    console.log("CAddresses initialized with contract addresses!");

    // Log final contract addresses
    console.log({
        GoodNft: goodNft.address,
        BadNft: badNft.address,
        CAddresses: cAddresses.address,
        NftValues: nftValues.address,
        CCollateralManager: cCollateralManager.address,
        NftTrader: nftTrader.address,
        CLendingPool: cLendingPool.address,
    });

    const filePath = path.join(__dirname, "deployedAddresses.json");
    fs.writeFileSync(filePath, JSON.stringify(deployedAddresses, null, 2));
    console.log(`Deployed addresses saved to ${filePath}`);

    // Log final contract addresses
    console.log(deployedAddresses);
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });