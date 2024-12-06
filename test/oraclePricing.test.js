const { execSync } = require("child_process");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");


function getNftPrice(collection, tokenId, iteration) {
    try {
        const result = execSync(`python3 scripts/mockOracles/get_nft_price.py ${collection} ${tokenId} ${iteration}`);
        const output = result.toString().trim();
        console.log("python output:", output);
        return parseFloat(output);
    } catch (error) {
        console.error("Error executing Python script:", error.message);
        return NaN; // Handle errors gracefully
    }
}

describe("Sophisticated Oracle Pricing Mechanism", function () {
    let addresses, portal, lendingPool, collateralManager, nftTrader, nftValues, mockOracle, gNft, bNft;
    let addressesAddr, portalAddr, lendingPoolAddr, collateralManagerAddr, nftTraderAddr, nftValuesAddr, mockOracleAddr, gNftAddr, bNftAddr;
    let deployer, lender1, borrower1, borrower2, lender2, liquidator;
    let deployerAddr, lender1Addr, borrower1Addr, borrower2Addr, lender2Addr, liquidatorAddr;
    let useOnChainOracle = true;
    let gNftFP, bNftFP

    beforeEach(async function () {
        // Get signers
        [deployer, lender1, borrower1, borrower2, lender2, liquidator, ...others] = await ethers.getSigners();
        deployerAddr = deployer.address;
        console.log("deployers address:", deployerAddr);
        borrower1Addr = borrower1.address;
        console.log("borrower1 address:", borrower1Addr);
        borrower2Addr = borrower2.address;
        console.log("borrower2 address:", borrower2Addr);
        lender1Addr = lender1.address;
        console.log("lender1 address:", lender1Addr);
        lender2Addr = lender2.address;
        console.log("lender2 address:", lender2Addr);
        liquidatorAddr = liquidator.address;
        console.log("liquidator address:", liquidatorAddr);

        // Deploy GoodNFT (Mock NFT contract)
        const GoodNFT = await ethers.getContractFactory("GoodNFT");
        gNft = await GoodNFT.connect(deployer).deploy();
        gNftAddr = await gNft.getAddress();
        console.log("GoodNft deployed at:", gNftAddr);
    
        // Deploy BadNFT (Mock NFT contract)
        const BadNFT = await ethers.getContractFactory("BadNFT");
        bNft = await BadNFT.connect(deployer).deploy();
        bNftAddr = await bNft.getAddress();
        console.log("BadNft deployed at:", bNftAddr);

        // Deploy Addresses
        const Addresses = await ethers.getContractFactory("Addresses");
        addresses = await Addresses.connect(deployer).deploy();
        addressesAddr = await addresses.getAddress();
        console.log("UserPortal deployed at:", addressesAddr);
    
        // Deploy MockOracle contract
        const MockOracle = await ethers.getContractFactory("MockOracle");
        mockOracle = await MockOracle.connect(deployer).deploy(addressesAddr);
        mockOracleAddr = await mockOracle.getAddress();
        console.log("MockOracle deployed at:", mockOracleAddr);
    
        // Deploy UserPortal
        const UserPortal = await ethers.getContractFactory("UserPortal");
        portal = await UserPortal.connect(deployer).deploy(addressesAddr);
        portalAddr = await portal.getAddress();
        console.log("UserPortal deployed at:", portalAddr);
    
        // Deploy LendingPool
        const LendingPool = await ethers.getContractFactory("LendingPool");
        lendingPool = await LendingPool.connect(deployer).deploy(addressesAddr);
        lendingPoolAddr = await lendingPool.getAddress();
        console.log("LendingPool deployed at:", lendingPoolAddr);
    
        // Deploy CollateralManager
        const CollateralManager = await ethers.getContractFactory("CollateralManager");
        collateralManager = await CollateralManager.connect(deployer).deploy(addressesAddr);
        collateralManagerAddr = await collateralManager.getAddress();
        console.log("CollateralManager deployed at:", collateralManagerAddr);
    
        // Deploy NftTrader
        const NftTrader = await ethers.getContractFactory("NftTrader");
        nftTrader = await NftTrader.connect(deployer).deploy(addressesAddr);
        nftTraderAddr = await nftTrader.getAddress();
        console.log("NftTrader deployed at:", nftTraderAddr);
    
        // Deploy NftValues
        const NftValues = await ethers.getContractFactory("NftValues");
        nftValues = await NftValues.connect(deployer).deploy(addressesAddr);
        nftValuesAddr = await nftValues.getAddress();
        console.log("NftValues deployed at:", nftValuesAddr);

        await addresses.connect(deployer).setAddress("GoodNft", gNftAddr);
        await addresses.connect(deployer).setAddress("BadNft", bNftAddr);
        await addresses.connect(deployer).setAddress("Addresses", addressesAddr);
        await addresses.connect(deployer).setAddress("NftValues", nftValuesAddr);
        await addresses.connect(deployer).setAddress("CollateralManager", collateralManagerAddr);
        await addresses.connect(deployer).setAddress("NftTrader", nftTraderAddr);
        await addresses.connect(deployer).setAddress("LendingPool", lendingPoolAddr);
        await addresses.connect(deployer).setAddress("UserPortal", portalAddr);
        await addresses.connect(deployer).setAddress("MockOracle", mockOracleAddr);
        await addresses.connect(deployer).setAddress("deployer", deployer.address);
    
        // Initialize contracts
        // Initialize MockOracle
        await mockOracle.connect(deployer).initialize();
    
        // Initialize NftValues
        await nftValues.connect(deployer).initialize(useOnChainOracle);
    
        // Initialize CollateralManager
        await collateralManager.connect(deployer).initialize();
    
        // Initialize NftTrader
        await nftTrader.connect(deployer).initialize();
    
        // Initialize LendingPool
        await lendingPool.connect(deployer).initialize();
    
        // Initialize UserPortal
        await portal.connect(deployer).initialize();
        console.log("All contracts initialized!");

        // Set initial collection prices in MockOracle
        // gNftFP = parseEther("10"); // 10 ETH floor price
        // console.log("Setting floor price for GoodNft collection to ...", gNftFP.toString());
        // const GNft_safe = true; // Collection is safe for borrowing
        // await mockOracle.connect(deployer).manualSetCollection(gNftAddr, gNftFP, GNft_safe);
        
        // bNftFP = parseEther("15"); // 15 ETH floor price
        // console.log("Setting floor price for BadNft collection to ...", bNftFP.toString());
        // const BNft_safe = true; // Collection is safe for borrowing
        // await mockOracle.connect(deployer).manualSetCollection(bNftAddr, bNftFP, BNft_safe);
    
        // Mint NFTs for borrower1 and borrower2
        console.log("Minting GoodNfts to borrower1 and borrower2... ");
        await gNft.connect(deployer).mint(borrower1Addr);
        await gNft.connect(deployer).mint(borrower2Addr);
        const owner0 = await gNft.ownerOf(0);
        const owner1 = await gNft.ownerOf(1);
        if (owner0 != borrower1Addr || owner1 != borrower2Addr) {
            throw new Error("borrower1 and borrower2 should own GoodNft tokenId 0 and 1 respectively.");
        }
    });

    describe("retreiving data from py", function () {
        it("should allow me to call the function", async function () {
            const price = getNftPrice("gNft", 0, 1);
            console.log("price retrieved from python script: ", price);
            // expect(price).to.equal(10);
        });
    });
});