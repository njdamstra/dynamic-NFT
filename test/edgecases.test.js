const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UserPortal", function () {
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
        gNftFP = parseEther("10"); // 10 ETH floor price
        console.log("Setting price for GoodNft collection token 0 to ...", gNftFP.toString());
        await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 0, gNftFP);

        await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 1, gNftFP);

        bNftFP = parseEther("15"); // 15 ETH floor price
        console.log("Setting price for BadNft token 0 to ...", bNftFP.toString());
        const BNft_safe = true; // Collection is safe for borrowing
        await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 0, bNftFP);


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

    //TODO
    // @ETest 1 - Borrow no collateral
    describe("[@ETest 1] - Borrow no collateral", function () {
        // SETUP
        beforeEach(async function () {
            //Lender 1 supplies 10 eth to the pool
            const amountLending = parseEther("100");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);
        });

        it("[@ETest 1] Borrower1 should not be able to borrow as he does not have any collateral in the lending system.", async function () {
            const borrower1BalanceBefore = await ethers.provider.getBalance(borrower1Addr);

            const amountBorrowing = parseEther("50");
            console.log("[@1.1] Calling borrow in Portal and listening for events...");
            // function call should be reverted
            await expect(
                portal.connect(borrower1).borrow(amountBorrowing)
            ).to.be.revertedWith("[*ERROR*] Health factor too low to borrow more money!");

            console.log("[@1.2] Checking borrowers balance before and after");
            const borrower1BalanceAfter = await ethers.provider.getBalance(borrower1Addr);
            expect(borrower1BalanceBefore).to.equal(borrower1BalanceAfter);

            //Check that Pool is unaffected
            console.log("[@1.3] Checking pools state before and after");
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            expect(poolBalanceAfter).to.equal(100);

            //Check Borrowers General Profile
            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("[@1.4] Checking the borrowers state");
            console.log("   [@1.4] Checking netDebt");
            const expectedNetDebt = parseEther("0");
            expect(netDebt).to.equal(expectedNetDebt);
            console.log("   [@1.4] Checking totalDebt");
            const expectedTotalDebt = 0 + (0*10) / 100;
            expect(totalDebt).to.equal(parseEther(expectedTotalDebt.toString()));
            console.log("   [@1.4] Checking totalSupplied");
            expect(totalSupplied).to.equal(0);
            console.log("   [@1.4] Checking collateralValue");
            expect(collateralValue).to.equal(0);

            //Check Borrowers Interest Profile
            console.log("[@1.5] Checking borrowers interest profile")
            const [periodicalInterest, initalTimeStamp, lastUpdated, periodDuration] = await lendingPool.connect(borrower1).getInterestProfile(borrower1Addr);
            console.log("   [@1.5] Checking periodical interest:", periodicalInterest.toString());

            console.log("   [@1.5] Checking inital timestamp:", initalTimeStamp.toString());

            console.log("   [@1.5] Checking last updated:", lastUpdated.toString());

            console.log("   [@1.5] Checking period duration:", periodDuration.toString());

            });
    });

    //TODO
    // @ETest 2 - Borrow undercollateralized
    describe("[@ETest 2] - Borrow undercollateralized", function () {
        // SETUP
        beforeEach(async function () {
            //Lender 1 supplies 10 eth to the pool
            const amountLending = parseEther("100");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);
        });

        it("[@ETest 2] Borrower1 should not be able to borrow as he does not have sufficient collateral in the lending system.", async function () {
            const borrower1BalanceBefore = await ethers.provider.getBalance(borrower1Addr);

            const amountBorrowing = parseEther("50");
            console.log("[@2.1] Calling borrow in Portal and listening for events...");

            // function call should be reverted
            await expect(
                portal.connect(borrower1).borrow(amountBorrowing)
            ).to.be.revertedWith("[*ERROR*] Health factor too low to borrow more money!");

            console.log("[@2.2] Checking borrowers balance before and after");
            const borrower1BalanceAfter = await ethers.provider.getBalance(borrower1Addr);
            expect(borrower1BalanceBefore).to.equal(borrower1BalanceAfter);

            //Check that Pool is unaffected
            console.log("[@2.3] Checking pools state before and after");
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            expect(poolBalanceAfter).to.equal(100);

            //Check Borrowers General Profile
            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("[@2.4] Checking the borrowers state");
            console.log("   [@2.4] Checking netDebt");
            const expectedNetDebt = parseEther("0");
            expect(netDebt).to.equal(expectedNetDebt);
            console.log("   [@2.4] Checking totalDebt");
            const expectedTotalDebt = 0 + (0*10) / 100;
            expect(totalDebt).to.equal(parseEther(expectedTotalDebt.toString()));
            console.log("   [@2.4] Checking totalSupplied");
            expect(totalSupplied).to.equal(0);
            console.log("   [@2.4] Checking collateralValue");
            expect(collateralValue).to.equal(0);

            //Check Borrowers Interest Profile
            console.log("[@2.5] Checking borrowers interest profile")
            const [periodicalInterest, initalTimeStamp, lastUpdated, periodDuration] = await lendingPool.connect(borrower1).getInterestProfile(borrower1Addr);
            console.log("   [@2.5] Checking periodical interest:", periodicalInterest.toString());

            console.log("   [@2.5] Checking inital timestamp:", initalTimeStamp.toString());

            console.log("   [@2.5] Checking last updated:", lastUpdated.toString());

            console.log("   [@2.5] Checking period duration:", periodDuration.toString());

        });
    });

    //TODO
    // @ETest 3 - Borrow zero amount
    describe("[@ETest 3] - Borrow zero amount", function () {
        // SETUP
        beforeEach(async function () {
            //Lender 1 supplies 10 eth to the pool
            const amountLending = parseEther("100");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);
        });

        it("[@ETest 3] Borrower1 should not be able to borrow zero amount.", async function () {
            const borrower1BalanceBefore = await ethers.provider.getBalance(borrower1Addr);

            const amountBorrowing = parseEther("1");
            console.log("[@3.1] Calling borrow in Portal and listening for events...");

            // function call should be reverted
            await expect(
                portal.connect(borrower1).borrow(amountBorrowing)
            ).to.be.revertedWith("[*ERROR*] Can not borrow zero ETH!");

            console.log("[@3.2] Checking borrowers balance before and after");
            const borrower1BalanceAfter = await ethers.provider.getBalance(borrower1Addr);
            expect(borrower1BalanceBefore).to.equal(borrower1BalanceAfter);

            //Check that Pool is unaffected
            console.log("[@3.3] Checking pools state before and after");
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            expect(poolBalanceAfter).to.equal(100);

            //Check Borrowers General Profile
            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("[@3.4] Checking the borrowers state");
            console.log("   [@3.4] Checking netDebt");
            const expectedNetDebt = parseEther("0");
            expect(netDebt).to.equal(expectedNetDebt);
            console.log("   [@3.4] Checking totalDebt");
            const expectedTotalDebt = 0 + (0*10) / 100;
            expect(totalDebt).to.equal(parseEther(expectedTotalDebt.toString()));
            console.log("   [@3.4] Checking totalSupplied");
            expect(totalSupplied).to.equal(0);
            console.log("   [@3.4] Checking collateralValue");
            expect(collateralValue).to.equal(0);

            //Check Borrowers Interest Profile
            console.log("[@3.5] Checking borrowers interest profile")
            const [periodicalInterest, initalTimeStamp, lastUpdated, periodDuration] = await lendingPool.connect(borrower1).getInterestProfile(borrower1Addr);
            console.log("   [@3.5] Checking periodical interest:", periodicalInterest.toString());

            console.log("   [@3.5] Checking inital timestamp:", initalTimeStamp.toString());

            console.log("   [@3.5] Checking last updated:", lastUpdated.toString());

            console.log("   [@3.5] Checking period duration:", periodDuration.toString());

        });
    });

    //TODO
    // @ETest 4 - Borrow max amount
    describe("[@ETest 4] - Borrow max amount", function () {
        // SETUP
        beforeEach(async function () {
            //Lender 1 supplies 10 eth to the pool
            const amountLending = parseEther("100");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);
        });

        it("[@ETest 4] Borrower1 should not be able to borrow max (amount > pool) amount.", async function () {
            const borrower1BalanceBefore = await ethers.provider.getBalance(borrower1Addr);

            const amountBorrowing = parseEther("99999999");
            console.log("[@4.1] Calling borrow in Portal and listening for events...");

            // function call should be reverted
            await expect(
                portal.connect(borrower1).borrow(amountBorrowing)
            ).to.be.revertedWith("[*ERROR*] Insufficient pool liquidity!");

            console.log("[@4.2] Checking borrowers balance before and after");
            const borrower1BalanceAfter = await ethers.provider.getBalance(borrower1Addr);
            expect(borrower1BalanceBefore).to.equal(borrower1BalanceAfter);

            //Check that Pool is unaffected
            console.log("[@4.3] Checking pools state before and after");
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            expect(poolBalanceAfter).to.equal(100);

            //Check Borrowers General Profile
            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("[@4.4] Checking the borrowers state");
            console.log("   [@4.4] Checking netDebt");
            const expectedNetDebt = parseEther("0");
            expect(netDebt).to.equal(expectedNetDebt);
            console.log("   [@4.4] Checking totalDebt");
            const expectedTotalDebt = 0 + (0*10) / 100;
            expect(totalDebt).to.equal(parseEther(expectedTotalDebt.toString()));
            console.log("   [@4.4] Checking totalSupplied");
            expect(totalSupplied).to.equal(0);
            console.log("   [@4.4] Checking collateralValue");
            expect(collateralValue).to.equal(0);

            //Check Borrowers Interest Profile
            console.log("[@4.5] Checking borrowers interest profile")
            const [periodicalInterest, initalTimeStamp, lastUpdated, periodDuration] = await lendingPool.connect(borrower1).getInterestProfile(borrower1Addr);
            console.log("   [@4.5] Checking periodical interest:", periodicalInterest.toString());

            console.log("   [@4.5] Checking inital timestamp:", initalTimeStamp.toString());

            console.log("   [@3.5] Checking last updated:", lastUpdated.toString());

            console.log("   [@3.5] Checking period duration:", periodDuration.toString());

        });
    });

    //TODO
    // @ETest 5 - addCollateral of not owned NFT
    describe("[@ETest 5] addCollateral of not owned NFT", function () {
        beforeEach(async function () {
            // lender1 supplies 10 ETH to the pool for liquidity
            const amountLending = parseEther("10");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
        });

        it("[@ETest 5] Borrower should not be allowed to add not owned NFT to collateral", async function () {
            // borrower1 approves portal to transfer their NFT
            console.log("Start testing it function 1... ");
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);

            // borrower1 adds NFT as collateral via portal
            console.log("listening for events... ");
            await expect(
                portal.connect(borrower1).addCollateral(gNftAddr, 1)
            ).to.be.revertedWith("[*ERROR*] NFT collateral is invalid!");

            // Verify that the NFT is not owned by the CollateralManager
            const nftOwner = await gNft.ownerOf(1);
            expect(nftOwner).to.equal(borrower2);

            // Check that the collateral profile does not include the NFT
            const profile = await collateralManager.getCollateralProfile(borrower1Addr);
            const nftListLength = profile.nftList.length;
            console.log("nftListLength:", nftListLength.toString());
            expect(nftListLength).to.equal(0);

        });
    });

    //TODO
    // @ETest 6 - redeemCollateral of not owned NFT
    describe("[@ETest 6] redeemCollateral of not owned NFT", function () {
        beforeEach(async function () {
            // lender1 supplies 10 ETH to the pool for liquidity
            const amountLending = parseEther("10");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });

            //borrower1 addsCollateral of gNft(0)
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0)
        });

        it("[@ETest 6] Borrower2 should not be allowed to redeem not owned NFT to collateral", async function () {
            //borrower 2 tries to redeem nft that is not his
            console.log("[@6] Starting Test")
            await expect(
                portal.connect(borrower2).redeemCollateral(gNftAddr, 0)
            ).to.be.revertedWith("[*ERROR* Nft not valid]");

            // Verify that the NFT is still owned by borrower2
            const nftOwner = await gNft.ownerOf(0);
            expect(nftOwner).to.equal(borrower1);

            // Check that the collateral profile of borrower1 does include the NFT
            const profile = await collateralManager.getCollateralProfile(borrower1Addr);
            const nftListLength = profile.nftList.length;
            console.log("nftListLength:", nftListLength.toString());
            expect(nftListLength).to.equal(1);

        });
    });

    //TODO
    // @ETest 7 - supply zero amount
    describe("supply zero amount", function () {
        it("should not allow lender1 to supply 0 ETH to the pool", async function () {
            const lenderBalBefore = await ethers.provider.getBalance(lender1Addr);
            const amountLending = parseEther("0");

            // Record initial pool balance
            const initialPoolBalance = await lendingPool.getPoolBalance();

            // lender1 supplies ETH via portal
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.revertedWith("[*ERROR*] supply: Cannot supply zero ETH!");

            // Check pool balance
            const poolBalance = await lendingPool.getPoolBalance();
            expect(poolBalance).to.equal(initialPoolBalance);

            // Check lender1's balance in LendingPool
            const lenderPoolBalance = await lendingPool.totalSuppliedUsers(lender1.address);
            expect(lenderPoolBalance).to.equal(amountLending);

            // Check lender1 balance before and after
            const lenderBalAfter = await ethers.provider.getBalance(lender1Addr);
            expect(lenderBalAfter).to.equal(lenderBalBefore);
        });
    });

    //TODO
    // @ETest 8 - supplying max support
    describe("supply max amount", function () {
        it("should not allow lender1 to supply 0 ETH to the pool", async function () {
            const lenderBalBefore = await ethers.provider.getBalance(lender1Addr);
            const amountLending = parseEther("999999999");

            // Record initial pool balance
            const initialPoolBalance = await lendingPool.getPoolBalance();

            // lender1 supplies ETH via portal
            await expect(
                portal.connect(lender1).supply(amountLending, { value: amountLending })
            ).to.revertedWith("[*ERROR*] Can not supply more than you own!");

            // Check pool balance
            const poolBalance = await lendingPool.getPoolBalance();
            expect(poolBalance).to.equal(initialPoolBalance);

            // Check lender1's balance in LendingPool
            const lenderPoolBalance = await lendingPool.totalSuppliedUsers(lender1.address);
            expect(lenderPoolBalance).to.equal(amountLending);

            // Check lender1 balance before and after
            const lenderBalAfter = await ethers.provider.getBalance(lender1Addr);
            expect(lenderBalAfter).to.equal(lenderBalBefore);
        });
    });

    //TODO
    // @ETest 9 - bidding
});