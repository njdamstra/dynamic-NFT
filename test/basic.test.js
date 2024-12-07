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
    // @RTest 1 - supply
    describe("Lender Functions", function () {
        it("should allow lender1 to supply 10 ETH to the pool", async function () {
            const lenderBalBefore = await ethers.provider.getBalance(lender1Addr);
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

          await expect(
            portal.connect(lender1).withdraw(amountLending)
          ).to.emit(lendingPool, "Withdrawn").withArgs(lender1Addr, amountLending);

          const lenderBalAfter = await ethers.provider.getBalance(lender1Addr);

          console.log("Lender1's balance before: ", lenderBalBefore.toString());
          console.log("Lender1's balance after: ", lenderBalAfter.toString());
        });
    });
    //TODO
    // @RTest 3 - add Collateral
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
          .and.to.emit(nftValues, "NftAdded").withArgs(
            gNftAddr,
            0,
            0,
            true
          )
          .and.to.emit(mockOracle, "RequestFromNftValues").withArgs(gNftAddr, 0);

          console.log("CM successful emited the CollateralAdded event");
    
          // Verify that the NFT is now owned by the CollateralManager
          const nftOwner = await gNft.ownerOf(0);
          expect(nftOwner).to.equal(collateralManagerAddr);
    
          // Check that the collateral profile includes the NFT
          const profile = await collateralManager.getCollateralProfile(borrower1Addr);
          const nftListLength = profile.nftList.length;
          console.log("nftListLength:", nftListLength.toString());
          expect(nftListLength).to.equal(1);
    
          // Retrieve NFT details from the profile
          // const nft = await collateralManager.borrowersCollateral(borrower1Addr);
          console.log("Confirming NFT details in Collateral Manager");
          const nftDetails = profile.nftList[0];
          expect(nftDetails.collectionAddress).to.equal(gNftAddr);
          expect(nftDetails.tokenId).to.equal(0);
    
          // Verify that the collection is registered in NftValues
          console.log("Confirming Collection details in NftValues");
          const nft = await nftValues.getNft(gNftAddr, 0);
          expect(nft.collection).to.equal(gNftAddr);
          expect(nft.price).to.equal(parseEther("10"));
          expect(nft.tokenId).to.equal(0);
          expect(nft.pending).to.be.false;
          expect(nft.notPending).to.be.true;
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
    //TODO
    // @RTest 4 - borrow
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
        it("should allow borrower1 to redeem their collateral!", async function () {
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

    //TODO
    // @ RTest
    describe("Contract recognizes Borrower is liquidatable", function () {
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
                mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 0, newGFP)
            ).to.emit(mockOracle, "UpdateNft").withArgs(gNftAddr, 0, newGFP);

            const floorPriceBefore = await nftValues.getNftPrice(gNftAddr, 0);
            console.log("Floor price of GoodNft before oracle updated NftValues:", floorPriceBefore.toString());
            expect(floorPriceBefore).to.equal(parseEther("10"));
            
            console.log("MockOracle updates nft price in NftValues");
            await expect(
                mockOracle.updateAllFloorPrices()
            ).to.emit(mockOracle, "SentUpdateToNftValues").withArgs(gNftAddr, 0, newGFP
            ).to.emit(nftValues, "NftPriceUpdated").withArgs(gNftAddr, 0, newGFP, anyValue);
            
            const floorPriceAfter = await collateralManager.getNftValue(gNftAddr, 0);
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

    //TODO
    // @RTest 8 - purchase Nft
    describe("NftTrader purchasing, bidding and delisting on one NFT", function () {
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
            await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 0, newGFP);
            
            await portal.connect(deployer).refresh(); // refresh to update floor prices in NftValues and add listing to NftTrader

            // await portal.connect(deployer).refresh(); // second refresh to add trade to NftTrader
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
        it("Should delist NFT listing if it's floor price increases", async function () {
            const boolBefore = await nftTrader.isListing(gNftAddr, 0);
            expect(boolBefore).to.be.true;

            const liqBefore = await collateralManager.getBeingLiquidated(borrower1Addr);
            console.log("borrower1 is liquidatable: ", liqBefore.toString());
            expect(liqBefore).to.be.true;
            
            const increaseGFP = parseEther("10");
            await expect(
                mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 0, increaseGFP)
            ).to.emit(mockOracle, "UpdateNft").withArgs(gNftAddr, 0, increaseGFP);

            // Refresh portal and check events step-by-step
            const tx = await portal.connect(deployer).refresh();

            // Check individual events
            await expect(tx).to.emit(mockOracle, "RequestFromNftValues").withArgs(gNftAddr, 0);
            await expect(tx).to.emit(mockOracle, "SentUpdateToNftValues").withArgs(gNftAddr, 0, increaseGFP);
            console.log("update floor price in NftValues to 10...");
            await expect(tx).to.emit(nftValues, "NftPriceUpdated").withArgs(gNftAddr, 0, increaseGFP, anyValue);
            
            console.log("check state...");
            const [, , , collateralValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);

            console.log("borrower1's total Collateral value:", collateralValue.toString());
            expect(collateralValue).to.equal(gNftFP);

            console.log("Borrower1's loans Health Factor:", hf.toString());
            expect(hf).to.equal(136);

            const liqAfter = await collateralManager.getBeingLiquidated(borrower1Addr);
            console.log("borrower1 is liquidatable: ", liqAfter.toString());
            expect(liqAfter).to.be.false;

            const boolAfter = await nftTrader.isListing(gNftAddr, 0);
            console.log("borrower1's NFT is still listed in NftTrader:", boolAfter.toString());
            expect(boolAfter).to.be.false;
            
            console.log("Listening for NftTrader emmitting NFTDelisted event...");
            await expect(tx).to.emit(nftTrader, "NFTDelisted").withArgs(gNftAddr, 0, anyValue);
            
            console.log("Listening for CM emitting NFTDeListed event...");
            await expect(tx).to.emit(collateralManager, "NFTDeListed").withArgs(borrower1Addr, gNftAddr, 0, anyValue);
        });
        it("should let borrower1 to add more collateral and have his trade delisted", async function () {
            await gNft.connect(deployer).mint(borrower1Addr);
            const gNft2 = parseEther("12"); // price of gNft tokenId 2
            await mockOracle.connect(deployer).manualUpdateNftPrice(gNftAddr, 2, gNft2);
            
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            const tx = await portal.connect(borrower1).addCollateral(gNftAddr, 2);

            expect(tx).to.emit(collateralManager, "NftDeListed").withArgs(
                borrower1Addr, gNftAddr, 0, anyValue);

        })
    });
    //TODO
    // @RTest
    describe("Borrower1 adds multiple NFTs as Collateral", function () {
        beforeEach(async function () {
            let amountLending1 = parseEther("10");
            await portal.connect(lender1).supply(amountLending1, { value: amountLending1 });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await gNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            await portal.connect(borrower1).addCollateral(gNftAddr, 0);

            await bNft.connect(deployer).mint(borrower1Addr);
        });
        it("Should allow Borrower1 add BadNft his Collateral Profile", async function () {
            // add 2nd collateral
            await bNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            const tx = await portal.connect(borrower1).addCollateral(bNftAddr, 0);

            // listen for the events
            await expect(tx).to.emit(collateralManager, "CollateralAdded").withArgs(
                borrower1Addr, bNftAddr, 0, anyValue, anyValue);
            await expect(tx).to.emit(nftValues, "NftAdded").withArgs(
                bNftAddr, 0, 0, true);
            await expect(tx).to.emit(mockOracle, "RequestFromNftValues").withArgs(bNftAddr, 0);
            
            // check collaterals profile total value
            const collateralValue = await collateralManager.getCollateralValue(borrower1Addr);
            console.log("Borrower1's total collaterals value with 2 NFTs:", collateralValue.toString());
            expect(collateralValue).to.equal(parseEther("25"));
            
            // lender2 adds 15 ethers to lending pool
            const amountLending1 = parseEther("10");
            const amountLending2 = parseEther("15");
            const tx2 = await portal.connect(lender2).supply(amountLending2, { value: amountLending2 });
            await expect(tx2).to.emit(lendingPool, "Supplied").withArgs(lender2Addr, amountLending2);

            const poolBal = await lendingPool.getPoolBalance();
            expect(poolBal).to.equal(amountLending1 + amountLending2);

            // Borrower2 adds gNFT to Collateral Profile
            await gNft.connect(borrower2).setApprovalForAll(portalAddr, true);
            const tx3 = await portal.connect(borrower2).addCollateral(gNftAddr, 1);
            await expect(tx3).to.emit(collateralManager, "CollateralAdded").withArgs(
                borrower2Addr, gNftAddr, 1, anyValue, anyValue);
            // await expect(tx3).to.not.emit(nftValues, "CollectionAdded")
            // .withArgs(gNftAddr, anyValue, true, anyValue);

            // borrower1 borrows 15 eth
            const amountBorrowing1 = parseEther("15");
            const tx4 = await portal.connect(borrower1).borrow(amountBorrowing1);
            await expect(tx4).to.emit(lendingPool, "Borrowed").withArgs(borrower1Addr, amountBorrowing1);
            
            // borrower2 borrowers 5 eth
            const amountBorrowing2 = parseEther("5");
            const tx5 = await portal.connect(borrower2).borrow(amountBorrowing2);
            await expect(tx5).to.emit(lendingPool, "Borrowed").withArgs(borrower2Addr, amountBorrowing2);

            // lender1 withdraws 4 Eth
            const withdraw1 = parseEther("4");
            const tx6 = await portal.connect(lender1).withdraw(withdraw1);
            await expect(tx6).to.emit(lendingPool, "Withdrawn").withArgs(lender1Addr, withdraw1);

            // borrower1 repays 10 eth
            const repay1 = parseEther("10");
            const tx7 = await portal.connect(borrower1).repay(repay1, { value: repay1 });
            await expect(tx7).to.emit(lendingPool, "Repaid").withArgs(borrower1Addr, repay1);
            
            const [totalDebt, netDebt, , colValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("Borrower1's total debt after repaying 10 ETH of his 15 ETH loan: ", totalDebt.toString());
            console.log("Borrower1's net debt: ", netDebt.toString());
            expect(netDebt).to.equal(parseEther("5"));
            console.log("Borrower1's total collateral value: ", colValue.toString());
            expect(colValue).to.equal(parseEther("25"));
            console.log("Borrower1's health factor:", hf.toString());

            // lender1 shouldn't have gotten interest yet
            const totalSupplied1 = await lendingPool.connect(lender1).totalSuppliedUsers(lender1Addr);
            expect(totalSupplied1).to.equal(parseEther("6"));


            // borrower1 redeems his BadNft
            const tx8 = await portal.connect(borrower1).redeemCollateral(gNftAddr, 0);
            await expect(tx8).to.emit(collateralManager, "CollateralRedeemed").withArgs(
                borrower1Addr, gNftAddr, 0);
            
            // borrower1 tries to redeem his GoodNft but fails
            await expect(
                portal.connect(borrower1).redeemCollateral(bNftAddr, 0)
            ).to.be.revertedWith("[*ERROR*] Health Factor would fall below 1.2 after redemption!");
        })
    })

    //TODO
    // Scenario
    describe("Dynamic Liquidation Scenarios", function () {
        beforeEach(async function () {
            // set NFT PRICES
            // bNft0 = parseEther("40");
            // await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 0, bNft0);
            bNft1 = parseEther("100");
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 1, bNft1);
            bNft2 = parseEther("20");
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 2, bNft2);
            bNft3 = parseEther("30");
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 3, bNft3);

            // mint BadNft to borrower1:
            await bNft.connect(deployer).mint(borrower1Addr);
            await bNft.connect(deployer).mint(borrower1Addr);
            await bNft.connect(deployer).mint(borrower1Addr);
            await bNft.connect(deployer).mint(borrower1Addr);

            let amountLending1 = parseEther("150");
            await portal.connect(lender1).supply(amountLending1, { value: amountLending1 });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await bNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            // await portal.connect(borrower1).addCollateral(bNftAddr, 0);
            await portal.connect(borrower1).addCollateral(bNftAddr, 1);
            await portal.connect(borrower1).addCollateral(bNftAddr, 2);
            await portal.connect(borrower1).addCollateral(bNftAddr, 3);

            amountBorrowing1 = parseEther("45");
            await portal.connect(borrower1).borrow(amountBorrowing1);
        });
        it("should only liquidate some of borrower1's NFTs", async function () {
            const newBNft1 = parseEther("15");
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 1, newBNft1);
            await portal.connect(borrower1).refresh();
            // await portal.connect(borrower1).refresh();

            

            const [totalDebt, netDebt, , colValue, hf] = await lendingPool.connect(borrower1).getUserAccountData(borrower1Addr);
            console.log("Borrower1's total debt: ", totalDebt.toString());
            console.log("Borrower1's net debt: ", netDebt.toString());
            // expect(netDebt).to.equal(parseEther("5"));
            console.log("Borrower1's total collateral value: ", colValue.toString());
            // expect(colValue).to.equal(parseEther("25"));
            console.log("Borrower1's health factor:", hf.toString());

            // const b0listing = await nftTrader.isListing(bNftAddr, 0);
            const b1listing = await nftTrader.isListing(bNftAddr, 1);
            const b2listing = await nftTrader.isListing(bNftAddr, 2);
            const b3listing = await nftTrader.isListing(bNftAddr, 3);

            // console.log("bNft0 is listing in trader:", b0listing.toString());
            console.log("bNft1 is listing in trader:", b1listing.toString());
            console.log("bNft2 is listing in trader:", b2listing.toString());
            console.log("bNft3 is listing in trader:", b3listing.toString());

            expect(b1listing).to.be.false;
            expect(b2listing).to.be.false;
            expect(b3listing).to.be.true;

            const result = await collateralManager.connect(deployer).getNFTsToLiquidate(borrower1Addr);
            const nftsToLiquidate = result[0];
            const nftsNotToLiquidate = result[1];
            console.log("length of nftsToLiquidate:", nftsToLiquidate.length);
            console.log("length of nftsNotToLiquidate:", nftsNotToLiquidate.length);
            expect(nftsToLiquidate.length).to.equal(1);
            expect(nftsNotToLiquidate.length).to.equal(2);
        });
    });
    //TODO

    describe("Interest increases", function () {
        beforeEach( async function () {
            bNft1 = parseEther("100");
            await mockOracle.connect(deployer).manualUpdateNftPrice(bNftAddr, 1, bNft1);

            // mint BadNft to borrower1:
            await bNft.connect(deployer).mint(borrower1Addr);
            await bNft.connect(deployer).mint(borrower1Addr);

            let amountLending1 = parseEther("150");
            await portal.connect(lender1).supply(amountLending1, { value: amountLending1 });
            // borrower1 adds NFT GoodNft tokenId1 as collateral via portal
            await bNft.connect(borrower1).setApprovalForAll(portalAddr, true);
            // await portal.connect(borrower1).addCollateral(bNftAddr, 0);
            await portal.connect(borrower1).addCollateral(bNftAddr, 1);

            amountBorrowing1 = parseEther("50");
            await portal.connect(borrower1).borrow(amountBorrowing1);
        })
        it("Should increase total debt by 2% after 30 days", async function () {
            const [totalDebt, netDebt, , , hf] = await lendingPool.getUserAccountData(borrower1Addr);
            expect(netDebt).to.equal(parseEther("50"));
            expect(totalDebt).to.equal(parseEther("55"));
            expect(hf).to.equal(136);
            console.log("increasing time by 30 * 24 * 60 * 60 seconds")
            await network.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // Increase time by 20002 seconds
            await network.provider.send("evm_mine");
            await portal.connect(deployer).refresh();
            const [totalDebt2, netDebt2, , , hf2] = await lendingPool.getUserAccountData(borrower1Addr);
            console.log("total debt after 30 days:", totalDebt2);
            console.log("net debt after 30 days:", netDebt2);
            console.log("hf after 30 days:", hf2);

            expect(totalDebt2).to.equal(parseEther((55 + 55*.02).toString()));
            expect(netDebt2).to.equal(parseEther("50"));
            expect(hf2).to.equal(133);
        })
    })
    

        // Additional borrower tests...



});