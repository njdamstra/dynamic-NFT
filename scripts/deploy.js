require("dotenv").config();
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    // Set up provider and deployer
    const provider = new ethers.providers.JsonRpcProvider(process.env.ALCHEMY_SEPOLIA_RPC_URL);
    const deployer = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);

    console.log("Deploying contracts with:", deployer.address);

    const deployedAddresses = {}; // Initialize the deployedAddresses object

    // Deploy GoodNft (Mock NFT contract)
    const GNft = await ethers.getContractFactory("GoodNFT", deployer);
    const gNft = await GNft.deploy();
    await gNft.deployed();
    const gNftAddr = gNft.address;
    deployedAddresses["GoodNft"] = gNftAddr;
    console.log("GoodNft deployed to:", gNftAddr);

    // Deploy BadNft (Mock NFT contract)
    const BNft = await ethers.getContractFactory("BadNFT", deployer);
    const bNft = await BNft.deploy();
    await bNft.deployed();
    const bNftAddr = bNft.address;
    deployedAddresses["BadNft"] = bNftAddr;
    console.log("BadNft deployed to:", bNftAddr);

    // Deploy CAddresses
    const CAddresses = await ethers.getContractFactory("Addresses", deployer);
    const addresses = await CAddresses.deploy();
    await addresses.deployed();
    const addressesAddr = addresses.address;
    deployedAddresses["CAddresses"] = addressesAddr;
    console.log("CAddresses deployed to:", addressesAddr);

    // Deploy MockOracle contract
    const MockOracle = await ethers.getContractFactory("MockOracle", deployer);
    const mockOracle = await MockOracle.deploy(addressesAddr);
    await mockOracle.deployed();
    const mockOracleAddr = mockOracle.address;
    deployedAddresses["MockOracle"] = mockOracleAddr;
    console.log("MockOracle deployed to:", mockOracleAddr);

    // Deploy UserPortal
    const UserPortal = await ethers.getContractFactory("UserPortal", deployer);
    const portal = await UserPortal.deploy(addressesAddr);
    await portal.deployed();
    const portalAddr = portal.address;
    deployedAddresses["UserPortal"] = portalAddr;
    console.log("UserPortal deployed to:", portalAddr);

    // Deploy CLendingPool
    const CLendingPool = await ethers.getContractFactory("LendingPool", deployer);
    const pool = await CLendingPool.deploy(addressesAddr);
    await pool.deployed();
    const poolAddr = pool.address;
    deployedAddresses["CLendingPool"] = poolAddr;
    console.log("CLendingPool deployed to:", poolAddr);

    // Deploy CCollateralManager
    const CCollateralManager = await ethers.getContractFactory("CollateralManager", deployer);
    const collateralManager = await CCollateralManager.deploy(addressesAddr);
    await collateralManager.deployed();
    const CMAddr = collateralManager.address;
    deployedAddresses["CCollateralManager"] = CMAddr;
    console.log("CCollateralManager deployed to:", CMAddr);

    // Deploy NftTrader
    const NftTrader = await ethers.getContractFactory("NftTrader", deployer);
    const nftTrader = await NftTrader.deploy(addressesAddr);
    await nftTrader.deployed();
    const traderAddr = nftTrader.address;
    deployedAddresses["NftTrader"] = traderAddr;
    console.log("NftTrader deployed to:", traderAddr);

    // Deploy NftValues
    const NftValues = await ethers.getContractFactory("NftValues", deployer);
    const nftValues = await NftValues.deploy(addressesAddr);
    await nftValues.deployed();
    const nftValuesAddr = nftValues.address;
    deployedAddresses["NftValues"] = nftValuesAddr;
    console.log("NftValues deployed to:", nftValuesAddr);

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

    // Initialize MockOracle
    await mockOracle.initialize();
    
    // Initialize NftValues
    const useOnChainOracle = true;
    await nftValues.initialize(useOnChainOracle);

    // Initialize CollateralManager
    await collateralManager.initialize();

    // Initialize NftTrader
    await nftTrader.initialize();

    // Initialize LendingPool
    await pool.initialize();

    // Initialize UserPortal
    await portal.initialize();
    console.log("All contracts initialized!");

    // Save deployed addresses to a file
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


