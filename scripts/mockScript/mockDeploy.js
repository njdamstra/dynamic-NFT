require("dotenv").config();
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
const signerData = require("./signers.json");

async function main() {
    // SET BOOLEAN (use mock oracle = true, use API oracle = false);
    const useOnChainOracle = false;
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

    // Deploy CAddresses
    const CAddresses = await ethers.getContractFactory("Addresses");
    const addresses = await CAddresses.deploy();
    const addressesAddr = await addresses.getAddress();
    deployedAddresses["CAddresses"] = addressesAddr;
    console.log("CAddresses deployed to:", addressesAddr);

    // Deploy MockOracle contract
    const MockOracle = await ethers.getContractFactory("MockOracle");
    const mockOracle = await MockOracle.connect(deployer).deploy(addressesAddr);
    const mockOracleAddr = await mockOracle.getAddress();
    deployedAddresses["MockOracle"] = mockOracleAddr;
    console.log("MockOracle deployed to:", mockOracleAddr);

    // Deploy UserPortal
    const UserPortal = await ethers.getContractFactory("UserPortal");
    const portal = await UserPortal.deploy(addressesAddr);
    const portalAddr = await portal.getAddress();
    deployedAddresses["UserPortal"] = portalAddr;
    console.log("UserPortal deployed to:", portalAddr);

    // Deploy CLendingPool
    const CLendingPool = await ethers.getContractFactory("LendingPool");
    const pool = await CLendingPool.deploy(addressesAddr);
    const poolAddr = await pool.getAddress();
    deployedAddresses["CLendingPool"] = poolAddr;
    console.log("CLendingPool deployed to:", poolAddr);

    // Deploy CCollateralManager
    const CCollateralManager = await ethers.getContractFactory("CollateralManager");
    const collateralManager = await CCollateralManager.deploy(addressesAddr);
    const CMAddr = await collateralManager.getAddress();
    deployedAddresses["CCollateralManager"] = CMAddr;
    console.log("CCollateralManager deployed to:", CMAddr);

    // Deploy NftTrader
    const NftTrader = await ethers.getContractFactory("NftTrader");
    const nftTrader = await NftTrader.deploy(addressesAddr);
    const traderAddr = await nftTrader.getAddress();
    deployedAddresses["NftTrader"] = traderAddr;
    console.log("NftTrader deployed to:", traderAddr);

    // Deploy NftValues
    const NftValues = await ethers.getContractFactory("NftValues");
    const nftValues = await NftValues.deploy(addressesAddr);
    const nftValuesAddr = await nftValues.getAddress();
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
    await mockOracle.connect(deployer).initialize();
    
    // Initialize NftValues
    await nftValues.connect(deployer).initialize(useOnChainOracle);

    // Initialize CollateralManager
    await collateralManager.connect(deployer).initialize();

    // Initialize NftTrader
    await nftTrader.connect(deployer).initialize();

    // Initialize LendingPool
    await pool.connect(deployer).initialize();

    // Initialize UserPortal
    await portal.connect(deployer).initialize();
    console.log("All contracts initialized!");

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