const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UserPortal", function () {
    let portal, lendingPool, collateralManager, nftTrader, nftValues, mockOracle, gNft, bNft;
    let portalAddr, lendingPoolAddr, collateralManagerAddr, nftTraderAddr, nftValuesAddr, mockOracleAddr, gNftAddr, bNftAddr;
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
    
        // Deploy MockOracle contract
        const MockOracle = await ethers.getContractFactory("MockOracle");
        mockOracle = await MockOracle.connect(deployer).deploy();
        mockOracleAddr = await mockOracle.getAddress();
        console.log("MockOracle deployed at:", mockOracleAddr);
    
        // Deploy UserPortal
        const UserPortal = await ethers.getContractFactory("UserPortal");
        portal = await UserPortal.connect(deployer).deploy();
        portalAddr = await portal.getAddress();
        console.log("UserPortal deployed at:", portalAddr);
    
        // Deploy Addresses (if needed)
        // const Addresses = await ethers.getContractFactory("Addresses");
        // addresses = await Addresses.connect(deployer).deploy();
        // await addresses.deployed();
    
        // Deploy LendingPool
        const LendingPool = await ethers.getContractFactory("LendingPool");
        lendingPool = await LendingPool.connect(deployer).deploy();
        lendingPoolAddr = await lendingPool.getAddress();
        console.log("LendingPool deployed at:", lendingPoolAddr);
    
        // Deploy CollateralManager
        const CollateralManager = await ethers.getContractFactory("CollateralManager");
        collateralManager = await CollateralManager.connect(deployer).deploy();
        collateralManagerAddr = await collateralManager.getAddress();
        console.log("CollateralManager deployed at:", collateralManagerAddr);
    
        // Deploy NftTrader
        const NftTrader = await ethers.getContractFactory("NftTrader");
        nftTrader = await NftTrader.connect(deployer).deploy();
        nftTraderAddr = await nftTrader.getAddress();
        console.log("NftTrader deployed at:", nftTraderAddr);
    
        // Deploy NftValues
        const NftValues = await ethers.getContractFactory("NftValues");
        nftValues = await NftValues.connect(deployer).deploy();
        nftValuesAddr = await nftValues.getAddress();
        console.log("NftValues deployed at:", nftValuesAddr);
    
        // Initialize contracts
        // Initialize MockOracle
        await mockOracle.connect(deployer).initialize(nftValuesAddr);
    
        // Initialize NftValues
        await nftValues.connect(deployer).initialize(collateralManagerAddr, useOnChainOracle, mockOracleAddr);
    
        // Initialize CollateralManager
        await collateralManager.connect(deployer).initialize(
          lendingPoolAddr,
          nftTraderAddr,
          nftValuesAddr,
          portalAddr
        );
    
        // Initialize NftTrader
        await nftTrader.connect(deployer).initialize(collateralManagerAddr, lendingPoolAddr, portalAddr);
    
        // Initialize LendingPool
        await lendingPool.connect(deployer).initialize(collateralManagerAddr, portalAddr, nftTraderAddr);
    
        // Initialize UserPortal
        await portal.connect(deployer).initialize(collateralManagerAddr, lendingPoolAddr, nftTraderAddr);
        console.log("All contracts initialized!");

        // Set initial collection prices in MockOracle
        gNftFP = parseEther("10"); // 10 ETH floor price
        console.log("Setting floor price for GoodNft collection to ...", gNftFP.toString());
        const GNft_safe = true; // Collection is safe for borrowing
        await mockOracle.connect(deployer).manualSetCollection(gNftAddr, gNftFP, GNft_safe);
        
        bNftFP = parseEther("15"); // 15 ETH floor price
        console.log("Setting floor price for BadNft collection to ...", bNftFP.toString());
        const BNft_safe = true; // Collection is safe for borrowing
        await mockOracle.connect(deployer).manualSetCollection(bNftAddr, bNftFP, BNft_safe);
    
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

    describe("Lender Functions", function () {
        it("should allow lender1 to supply 10 ETH to the pool", async function () {
          const amountLending = parseEther("10");
    
          // Record initial pool balance
          const initialPoolBalance = await lendingPool.getPoolBalance();
    
          // lender1 supplies ETH via portal
          await expect(
            portal.connect(lender1).supply(amountLending, { value: amountLending })
          ).to.emit(lendingPool, "Supplied").withArgs(lender1.address, amountLending);
    
          // Check pool balance
          const poolBalance = await lendingPool.getPoolBalance();
          expect(poolBalance).to.equal(initialPoolBalance + amountLending);
    
          // Check lender1's balance in LendingPool
          const lenderBalance = await lendingPool.totalSuppliedUsers(lender1.address);
          expect(lenderBalance).to.equal(amountLending);
        });
    });

    describe("Borrower Adds Collateral Once", function () {
        beforeEach(async function () {
          // lender1 supplies 10 ETH to the pool for liquidity
          const amountLending = parseEther("10");
          await portal.connect(lender1).supply(amountLending, { value: amountLending });
        });
    
        it("should allow borrower1 to add NFT as collateral", async function () {
            // borrower1 approves portal to transfer their NFT
          console.log("Start testing it function 1... ");
          await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
    
          // borrower1 adds NFT as collateral via portal
          console.log("listening for events... ");
          await expect(
            portal.connect(borrower1).addCollateral(gNftAddr, 0)
          ).to.emit(collateralManager, "CollateralAdded").withArgs(
            borrower1Addr,
            gNftAddr,
            0,
            anyValue, // Placeholder for value (since value is not specified in event)
            anyValue  // Placeholder for timestamp
          )
          .and.to.emit(nftValues, "CollectionAdded").withArgs(
            gNftAddr,
            0,
            true,
            anyValue
          )
          .and.to.emit(mockOracle, "RequestFromNftValues").withArgs(gNftAddr);

          console.log("CM successful emited the CollateralAdded event");
    
          // Verify that the NFT is now owned by the CollateralManager
          const nftOwner = await gNft.ownerOf(0);
          expect(nftOwner).to.equal(collateralManagerAddr);
    
          // Check that the collateral profile includes the NFT
          const profile = await collateralManager.getCollateralProfile(borrower1Addr);
          console.log("nftListLength:", profile.nftListLength.toString());
          expect(profile.nftListLength).to.equal(1);
    
          // Retrieve NFT details from the profile
          // const nft = await collateralManager.borrowersCollateral(borrower1Addr);
          console.log("Confirming NFT details in Collateral Manager");
          const nftDetails = profile.nftList[0];
          expect(nftDetails.collectionAddress).to.equal(gNftAddr);
          expect(nftDetails.tokenId).to.equal(0);
    
          // Verify that the collection is registered in NftValues
          console.log("Confirming Collection details in NftValues");
          const collection = await nftValues.getCollection(gNftAddr);
          expect(collection.collection).to.equal(gNftAddr);
          expect(collection.floorPrice).to.equal(parseEther("10"));
          expect(collection.safe).to.be.true;
          expect(collection.pending).to.be.false;
          expect(collection.notPending).to.be.true;
        });
    
        it("should fail if borrower1 tries to add an unapproved NFT as collateral", async function () {
          // Attempt to add NFT without approval
          await expect(
            portal.connect(borrower1).addCollateral(gNftAddr, 0)
          ).to.be.revertedWith("UserPortal not approved!");
        });

        it("should fail if borrower1 tries to add tokenId 1 as collateral", async function () {
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);

            await expect(
                portal.connect(borrower1).addCollateral(gNftAddr, 1)
            ).to.be.revertedWith("User is not the owner of this Nft");
        });

    });

    describe("Borrower Gets a Loan Using 1 NFT as Collateral", function () {
        beforeEach(async function () {
            // lender1 supplies 10 ETH to the pool for liquidity
            const amountLending = parseEther("10");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);
        });
        it("Should allow borrower1 to get a loan of 5 ETH", async function () {
            const amountBorrowing = parseEther("5");
            console.log("calling borrow in Portal and listening for events");
            await expect(
                portal.connect(borrower1).borrow(amountBorrowing)
            ).to.emit(lendingPool, "Borrowed").withArgs(borrower1Addr, amountBorrowing);

            console.log("now checking the pools state");
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            console.log("pools balance after taking out the loan: ", poolBalanceAfter.toString());
            expect(poolBalanceAfter).to.equal(amountBorrowing); // pools balance should be 5 Eth after taking out the loan of 5 Eth
            
            console.log("Check borrowers data");

            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);

            console.log("borrower1 net debt: ", netDebt.toString());
            const expectedNetDebt = parseEther("5");
            expect(netDebt).to.equal(amountBorrowing);

            console.log("borrower1 total debt: ", totalDebt.toString());
            const expectedTotalDebt = 5 + (5*10) / 100;
            expect(totalDebt).to.equal(parseEther(expectedTotalDebt.toString()));

            console.log("borrower1's total supplied to pool:", totalSupplied.toString());
            expect(totalSupplied).to.equal(0);

            console.log("borrower1's total Collateral value:", collateralValue.toString());
            expect(collateralValue).to.equal(gNftFP);

            console.log("Borrower1's loans Health Factor:", hf.toString());
            
            console.log("Borrower1's Interest Profile:")
            const [periodicalInterest, initalTimeStamp, lastUpdated, periodDuration] = await lendingPool.connect(borrower1).getInterestProfile(borrower1Addr);
            console.log("periodical interest:", periodicalInterest.toString());

            console.log("inital timestamp:", initalTimeStamp.toString());
            
            console.log("last updated:", lastUpdated.toString());

            console.log("period duration:", periodDuration.toString());

            const borrower1Balance = await ethers.provider.getBalance(borrower1Addr);
            console.log("Borrower1's ETH balance after borrowing: ", borrower1Balance.toString());
        });
        it("Should allow borrower1 to repay there loan of 5 Eth", async function () {
            const amountBorrowing = parseEther("5");
            console.log("borrow 5 Eth");
            await portal.connect(borrower1).borrow(amountBorrowing);
            
            const amountOwed = parseEther("5.5");
            console.log("repay the loan.");
            await expect(
                portal.connect(borrower1).repay(amountOwed, { value: amountOwed })
            ).to.emit(lendingPool, "Repaid").withArgs(borrower1Addr, amountOwed);

            console.log("Check borrowers data");

            const [totalDebt, netDebt, totalSupplied, collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);

            console.log("borrower1 net debt: ", netDebt.toString());
            const expectedNetDebt = 0;
            expect(netDebt).to.equal(expectedNetDebt);

            console.log("borrower1 total debt: ", totalDebt.toString());
            const expectedTotalDebt = 0;
            expect(totalDebt).to.equal(expectedTotalDebt);

            console.log("borrower1's total supplied to pool:", totalSupplied.toString());
            expect(totalSupplied).to.equal(0);

            console.log("borrower1's total Collateral value:", collateralValue.toString());
            expect(collateralValue).to.equal(gNftFP);

            console.log("Borrower1's loans Health Factor:", hf.toString());
            
            const poolBalanceAfter = await lendingPool.getPoolBalance();
            console.log("pools balance after taking out the loan: ", poolBalanceAfter.toString());
            expect(poolBalanceAfter).to.equal(amountBorrowing + amountOwed); // pools balance should be 10.5 Eth after taking out the loan of 5 Eth

            const [ , , totalSuppliedLender, , ] = await lendingPool.connect(lender1).getUserAccountData(lender1);
            console.log("total amount lender1 has supplied after interest: ", totalSuppliedLender);
            expect(totalSuppliedLender).to.equal(amountBorrowing + amountOwed);
        });
        it("should allow borrower1 to redeem there collateral!", async function () {
            const amountBorrowing = parseEther("5");
            console.log("borrow 5 Eth");
            await portal.connect(borrower1).borrow(amountBorrowing);
            
            const amountOwed = parseEther("5.5");
            console.log("repay the loan.");
            await portal.connect(borrower1).repay(amountOwed, { value: amountOwed });

            console.log("redeem collateral and listen for CollateralRedeemed event");
            await expect(
                portal.connect(borrower1).redeemCollateral(gNftAddr, 0)
            ).to.emit(collateralManager, "CollateralRedeemed").withArgs(borrower1Addr, gNftAddr, 0);
            
            console.log("Checking user data... ");
            const owner0 = await gNft.ownerOf(0);
            expect(owner0).to.equal(borrower1Addr);
        });

    });
    describe("Borrower gets his collateral liquidated", function () {
        beforeEach(async function () {
            let amountLending = parseEther("10");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);

            let amountBorrowing = parseEther("5");
            console.log("borrow 5 Eth");
            await portal.connect(borrower1).borrow(amountBorrowing);
        });
        it("Should liquidate nft if it's floor price changes to 5", async function () {
            const newGFP = parseEther("6");
            await expect(
                mockOracle.connect(deployer).manualUpdateFloorPrice(gNftAddr, newGFP)
            ).to.emit(mockOracle, "UpdateCollection").withArgs(gNftAddr, newGFP);

            const floorPriceBefore = await nftValues.getFloorPrice(gNftAddr);
            console.log("Floor price of GoodNft before oracle updated NftValues:", floorPriceBefore.toString());
            expect(floorPriceBefore).to.equal(parseEther("10"));
            
            console.log("MockOracle updates nft price in NftValues");
            await expect(
                mockOracle.updateAllFloorPrices()
            ).to.emit(mockOracle, "SentUpdateToNftValues").withArgs(gNftAddr, newGFP, true
            ).to.emit(nftValues, "FloorPriceUpdated").withArgs(gNftAddr, newGFP, true, anyValue);
            
            const floorPriceAfter = await collateralManager.getNftValue(gNftAddr);
            expect(floorPriceAfter).to.equal(newGFP);

            console.log("Check borrowers data");

            const [, , , collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);

            console.log("borrower1's total Collateral value:", collateralValue.toString());
            expect(collateralValue).to.equal(newGFP);

            console.log("Borrower1's loans Health Factor:", hf.toString());
            expect(hf).to.lessThan(120);

            const basePrice = parseEther((6*95/100).toString());
            console.log("Base price NFT is listed for:", basePrice);
            
            await expect(
                portal.connect(deployer).refresh()
            ).to.emit(collateralManager, "NFTListed").withArgs(
                borrower1Addr, gNftAddr, 0, basePrice, anyValue
            ).to.emit(nftTrader, "NFTListed").withArgs(
                gNftAddr, 0, basePrice, collateralManagerAddr, true, anyValue
            );
        });
    });

    describe("NftTrader purchasing and bidding on NFTs", function () {
        beforeEach(async function () {
            let amountLending = parseEther("10");
            await portal.connect(lender1).supply(amountLending, { value: amountLending });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);

            const amountBorrowing = parseEther("5");
            console.log("borrow 5 Eth");
            await portal.connect(borrower1).borrow(amountBorrowing);

            const newGFP = parseEther("6");
            await mockOracle.connect(deployer).manualUpdateFloorPrice(gNftAddr, newGFP);
            await mockOracle.updateAllFloorPrices();

            const basePrice = parseEther((6*95/100).toString());
            
            await portal.connect(deployer).refresh();
        });
        it("should let me purchase nft after auction ends", async function () {

            console.log("increasing time by 20002 seconds")
            await network.provider.send("evm_increaseTime", [20002]); // Increase time by 20002 seconds
            await network.provider.send("evm_mine");

            await expect(
                portal.connect(deployer).refresh()
            ).to.emit(nftTrader, "AuctionEndedWithNoWinner").withArgs(
                gNftAddr,
                0
            );

            const basePrice = parseEther((6*95/100).toString());

            await expect(
                portal.connect(liquidator).purchase(gNftAddr, 0, { value: basePrice })
            ).to.emit(nftTrader, "NFTPurchased").withArgs(
                gNftAddr, 0, basePrice, liquidatorAddr, anyValue
            ).to.emit(lendingPool, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, basePrice
            ).to.emit(lendingPool, "Repaid").withArgs(
                borrower1Addr, parseEther("5.5")
            ).to.emit(collateralManager, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, basePrice, anyValue
            );

            const owner0 = await gNft.ownerOf(0);
            expect(owner0).to.equal(liquidatorAddr);

        });
        it("should let me bid on it and I win", async function () {
            const bid1 = parseEther("6");
            await expect(
                portal.connect(liquidator).placeBid(gNftAddr, 0, { value: bid1 })
            ).to.emit(nftTrader, "NewBid").withArgs(liquidatorAddr, gNftAddr, 0, bid1)
            
            console.log("increasing time by 20002 seconds")
            await network.provider.send("evm_increaseTime", [20002]); // Increase time by 20002 seconds
            await network.provider.send("evm_mine");
            
            await expect(
                portal.connect(deployer).refresh()
            ).to.emit(nftTrader, "AuctionWon").withArgs(
                liquidatorAddr,
                gNftAddr,
                0,
                bid1
            ).to.emit(lendingPool, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, bid1
            ).to.emit(lendingPool, "Repaid").withArgs(
                borrower1Addr, parseEther("5.5")
            ).to.emit(collateralManager, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, bid1, anyValue
            );

            const owner0 = await gNft.ownerOf(0);
            expect(owner0).to.equal(liquidatorAddr);
        });
        it("Should let multiple liquidators place bids but only let the highest bid win", async function () {
            const bid1 = parseEther("5");
            const bid2 = parseEther("6");
            const bid3 = parseEther("7");

            console.log("tries to place 5 Eth bid on NFT who's base price is 5.75 Eth");
            await expect(
                portal.connect(lender1).placeBid(gNftAddr, 0, { value: bid1 })
            ).to.be.revertedWith("Bid not high enough");
            
            const lenderBalanceBefore = await ethers.provider.getBalance(lender1Addr);
            await expect(
                portal.connect(lender1).placeBid(gNftAddr, 0, { value: bid2 })
            ).to.emit(nftTrader, "NewBid").withArgs(lender1Addr, gNftAddr, 0, bid2);
            const lenderBalanceAfterBid = await ethers.provider.getBalance(lender1Addr);

            console.log("tries to place a bid with same amount as previous highest bid");
            await expect(
                portal.connect(liquidator).placeBid(gNftAddr, 0, { value: bid2 })
            ).to.be.revertedWith("Bid not high enough");
            
            console.log("Liquidator placed highest bid of 7 ETH");
            await expect(
                portal.connect(liquidator).placeBid(gNftAddr, 0, { value: bid3 })
            ).to.emit(nftTrader, "NewBid").withArgs(liquidatorAddr, gNftAddr, 0, bid3);
            const lenderBalanceLost = await ethers.provider.getBalance(lender1Addr);

            console.log("lender1 gets there money back after losing bid minus gas cost");
            expect(lenderBalanceBefore).to.greaterThanOrEqual(lenderBalanceLost);
            expect(lenderBalanceLost).to.greaterThan(lenderBalanceAfterBid)

            console.log("increasing time by 20002 seconds")
            await network.provider.send("evm_increaseTime", [20002]); // Increase time by 20002 seconds
            await network.provider.send("evm_mine");
            
            await expect(
                portal.connect(deployer).refresh()
            ).to.emit(nftTrader, "AuctionWon").withArgs(
                liquidatorAddr,
                gNftAddr,
                0,
                bid3
            ).to.emit(lendingPool, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, bid3
            ).to.emit(lendingPool, "Repaid").withArgs(
                borrower1Addr, parseEther("5.5")
            ).to.emit(collateralManager, "Liquidated").withArgs(
                borrower1Addr, gNftAddr, 0, bid3, anyValue
            );

            const owner0 = await gNft.ownerOf(0);
            expect(owner0).to.equal(liquidatorAddr);
        });
    });
    

        // Additional borrower tests...



});