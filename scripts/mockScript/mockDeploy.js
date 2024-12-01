require("dotenv").config();
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
const signerData = require("./signers.json");

async function main() {
    // Load named wallets
    const wallets = signerData.reduce((acc, signer) => {
        acc[signer.name] = new ethers.Wallet(signer.privateKey, ethers.provider);
        return acc;
    }, {});

    const deployer = wallets["deployer"];

    console.log("Deploying contracts with:", deployer.address);

    const deployedAddresses = {}; // Initialize the deployedAddresses object

    // Deploy GoodNft (Mock NFT contract)
    const GNft = await ethers.getContractFactory("GoodNFT");
    const gNft = await GNft.deploy();
    const gNftAddr = await gNft.getAddress();
    deployedAddresses["GoodNft"] = gNftAddr;
    console.log("GoodNft deployed to:", gNftAddr);

    // Deploy BadNft (Mock NFT contract)
    const BNft = await ethers.getContractFactory("BadNFT");
    const bNft = await BNft.deploy();
    const bNftAddr = await bNft.getAddress();
    deployedAddresses["BadNft"] = bNftAddr;
    console.log("BadNft deployed to:", bNftAddr);

    // Deploy MockOracle contract
    const MockOracle = await ethers.getContractFactory("MockOracle");
    const mockOracle = await MockOracle.connect(deployer).deploy();
    const mockOracleAddr = await mockOracle.getAddress();
    deployedAddresses["MockOracle"] = mockOracleAddr;
    console.log("MockOracle deployed to:", mockOracleAddr);

    // Deploy UserPortal
    const UserPortal = await ethers.getContractFactory("UserPortal");
    const portal = await UserPortal.deploy();
    const portalAddr = await portal.getAddress();
    deployedAddresses["UserPortal"] = portalAddr;
    console.log("UserPortal deployed to:", portalAddr);

    // Deploy CAddresses
    const CAddresses = await ethers.getContractFactory("Addresses");
    const addresses = await CAddresses.deploy();
    const addressesAddr = await addresses.getAddress();
    deployedAddresses["CAddresses"] = addressesAddr;
    console.log("CAddresses deployed to:", addressesAddr);

    // Deploy CLendingPool
    const CLendingPool = await ethers.getContractFactory("LendingPool");
    const pool = await CLendingPool.deploy();
    const poolAddr = await pool.getAddress();
    deployedAddresses["CLendingPool"] = poolAddr;
    console.log("CLendingPool deployed to:", poolAddr);

    // Deploy CCollateralManager
    const CCollateralManager = await ethers.getContractFactory("CollateralManager");
    const collateralManager = await CCollateralManager.deploy();
    const CMAddr = await collateralManager.getAddress();
    deployedAddresses["CCollateralManager"] = CMAddr;
    console.log("CCollateralManager deployed to:", CMAddr);

    // Deploy NftTrader
    const NftTrader = await ethers.getContractFactory("NftTrader");
    const nftTrader = await NftTrader.deploy();
    const traderAddr = await nftTrader.getAddress();
    deployedAddresses["NftTrader"] = traderAddr;
    console.log("NftTrader deployed to:", traderAddr);

    // Deploy NftValues
    const NftValues = await ethers.getContractFactory("NftValues");
    const nftValues = await NftValues.deploy();
    const nftValuesAddr = await nftValues.getAddress();
    deployedAddresses["NftValues"] = nftValuesAddr;
    console.log("NftValues deployed to:", nftValuesAddr);

    // Initialize contracts
    console.log("Initializing contracts...");

    // Initialize MockOracle:
    await mockOracle.initialize(nftValuesAddr);
    console.log("MockOracle initialized.");

    // Initialize CCollateralManager
    await collateralManager.initialize(
        poolAddr,
        traderAddr,
        nftValuesAddr,
        portalAddr
    );
    console.log("CCollateralManager initialized.");

    // Initialize NftTrader
    await nftTrader.initialize(CMAddr, poolAddr, portalAddr);
    console.log("NftTrader initialized.");

    // Initialize CLendingPool
    await pool.initialize(CMAddr, portalAddr, traderAddr);
    console.log("CLendingPool initialized.");

    // Initialize UserPortal
    await portal.initialize(CMAddr, poolAddr, traderAddr);
    console.log("UserPortal initialized.");

    // Initialize CAddresses with contract addresses
    await addresses.setAddress("GoodNft", gNftAddr);
    await addresses.setAddress("BadNft", bNftAddr);
    await addresses.setAddress("Addresses", addressesAddr);
    await addresses.setAddress("NftValues", nftValuesAddr);
    await addresses.setAddress("CollateralManager", CMAddr);
    await addresses.setAddress("NftTrader", traderAddr);
    await addresses.setAddress("LendingPool", poolAddr);
    await addresses.setAddress("UserPortal", portalAddr);
    await addresses.setAddress("MockOracle", mockOracleAddr);
    await addresses.setAddress("deployer", deployer.address);

    console.log("Addresses contract initialized with contract addresses!");

    // Log final contract addresses
    console.log({
        deployer: deployer.address,
        GoodNft: gNftAddr,
        BadNft: bNftAddr,
        CAddresses: addressesAddr,
        NftValues: nftValuesAddr,
        CCollateralManager: CMAddr,
        NftTrader: traderAddr,
        CLendingPool: poolAddr,
        UserPortal: portalAddr,
        MockOracle: mockOracleAddr,
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