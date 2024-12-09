const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UserPortal", function () {
    let addresses, portal, lendingPool, collateralManager, nftTrader, nftValues, mockOracle, gNft, bNft;
    let addressesAddr, portalAddr, lendingPoolAddr, collateralManagerAddr, nftTraderAddr, nftValuesAddr, mockOracleAddr,
        gNftAddr, bNftAddr;
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
        gNftFP = parseEther("10"); // 10 ETH floor price
        console.log("Setting price for GoodNft collection token 0 to ...", gNftFP.toString());
        await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 0, gNftFP);
        await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 1, gNftFP);

        bNftFP = parseEther("20"); // 15 ETH floor price
        console.log("Setting price for BadNft token 0 to ...", bNftFP.toString());
        const BNft_safe = true; // Collection is safe for borrowing
        await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 0, bNftFP);

        // Mint NFTs for borrower1 and borrower2
        console.log("Minting GoodNfts to borrower1 and borrower2... ");
        await gNft.connect(deployer).mint(borrower1Addr);
        await gNft.connect(deployer).mint(borrower2Addr);
        await bNft.connect(deployer).mint(borrower1Addr)
        const gowner0 = await gNft.ownerOf(0); //borrower1
        const gowner1 = await gNft.ownerOf(1); //borrower2
        const bowner0 = await gNft.ownerOf(0); //borrower1
        if (gowner0 != borrower1Addr || gowner1 != borrower2Addr) {
            throw new Error("borrower1 and borrower2 should own GoodNft tokenId 0 and 1 respectively.");
        }
    });

    describe("[Scenario 1] Volatility", function () {

        it("", async function () {
            // supply 1000 to pool
            const amountLending = parseEther("1000");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            await expect(portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);

            // add bNft as collateral
            await bNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            portal.connect(borrower1).addCollateral(bNftAddr, 0)
            const nftOwner = await bNft.ownerOf(0);
            expect(nftOwner).to.equal(portalAddr);

            // borrow 10 eth
            const amountBorrowed = parseEther("10");
            await expect(portal.connect(borrower1).borrow(amountBorrowed)
            ).to.emit(lendingPool, "Borrowed").withArgs(borrower1Addr, amountBorrowed);

            //account data 1
            let borrowerAccountData = portal.connect(borrower1).getBorrowerAccountData()
            const [totalDebt, netDebt, collateralValue, healthFactor, periodicalInterest, lastUpdated, periodDuration
            ] = borrowerAccountData;

            expect(totalDebt).to.equal((amountBorrowed * 10) / 100);
            expect(netDebt).to.equal((amountBorrowed));
            console.log("collateralValue", collateralValue.toString());
            console.log("healthFactor", healthFactor.toString());
            expect(periodicalInterest).to.equal(2)

            //price drop nft - 10% -> 20 to 18
            bNftFP = parseEther("18"); // 15 ETH floor price
            console.log("Setting price for BadNft token 0 to:.", bNftFP.toString());
            const BNft_safe = true; // Collection is safe for borrowing
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 0, bNftFP);

            //account data 2
            borrowerAccountData = portal.connect(borrower1).getBorrowerAccountData();
            [totalDebt, netDebt, collateralValue, healthFactor, periodicalInterest, lastUpdated, periodDuration] = borrowerAccountData;

            expect(totalDebt).to.equal((amountBorrowed * 10) / 100);
            expect(netDebt).to.equal((amountBorrowed));
            console.log("collateralValue", collateralValue.toString());
            console.log("healthFactor", healthFactor.toString());
            expect(periodicalInterest).to.equal(2)

            //

        });
    });

});