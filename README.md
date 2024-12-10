# **CREDITUM**
## - **Dynamic NFT Collateralization Protocol**


---

# ***Key Implemented Features:***

---

# **Dynamic Liquidation Protocol**

**Purpose:** Due to volatile nature of NFTs, Borrowers already face high risk of liquidation, we aim to reduce borrowers risk of complete liquidation

**Challenges with liquidating NFTs:**
1. Due to the inseperable nature of NFTs, its hard to define a close factor to protect the borrower from complete liquidation.
2. It's hard to price the collateral during liquidation due to NFTs violatile nature, we can't have one consistent liquidation spread

**Solution:** 
1. Liquidate until health factor restores to avoid excessive liquidation
2. Allow for a 24 hour grace period for values to restore, the borrower repays enought debt, or the borrower recollateralizes


**Our protocol:**
1. Health Factor:
    - Health Factor = (total collateral value x 75) / total debt
    - Liquidation Threshold = 100; (LT defines the health factor at which liquidation is triggered)
    - Loan-to-Value Ratio = 75; (LTV defines maximum borrowing capacity relative to the collateral value)
    - total collateral value = sum(borrowers NFTs value)
    - total debt = (loan + (loan x 10%)) 
    - Liquidation is triggered if health factor drops below 100 with the goal of restoring the borrower's financial stability.
2. Triggering liquidation:
    - once health factor drops below 100, liquidation is triggered.
    - getNFTsToLiquidate identifies the minimal set of NFTs required to bring the Health Factor back to or above 100.
      - NFTs are sorted in descending order of value, ensuring higher-value NFTs are prioritized for liquidation, minimizing the number of assets liquidated.
    
3. Simulate liquidation: for each NFT in a borrowers liquidatable collateral profile sorted in descending order;
    - subtract its value from the simulated total collateral
    - subtract the debt reduction from the simulated total debt.
    - mark liquidatable
    - recalculate heath factor with new simulated values.
    - if health factor > 110; stop marking NFTs as liquidatable.
    - else repeat for the next NFT in borrowers collateral profile without restoring simulated total collateral and total debt value

4. Liquidating: list all the NFTs marked as liquidatable by adding it to a 24 hour auction in NftTrader. Set the base price with a 5% discount of the oracle valuated price

5. Unliquidation: if in the 24 hour period: 
  - the health factor increases to above or equal to 110 due to the following reasons:
      1. the nft value increases due to market flucuations
      2. the borrower repays enough of there debts
      3. or provides additional collateral that adds enough value, 
  - the NFT will be delisted from NftTrader and be safe in the borrowers collateral profile.
  - If there was no liquidators that placed a bid on it within the 24 hour period, the listing changes to a 'buyNow' state where any liquidator can purchase it immediately for it's base price, or it can be delisted for the same reasons mentioned above, which ever comes first.


### **Example of Borrower Friendly Liquidation**

**Borrowers position:**
* Total Debt: 50 eth
* Total Collateral Value: 60 eth
  * NFT 1: 20 eth
  * NFT 2: 20 eth
  * NFT 3: 15 eth
  * NFT 4: 5 eth
* Health Factor: 60 x 75 / 50 = 90 
  * Liquidation is triggered (90 < 100)

**Liquidation Process:**
* NFTs sorted in descending order: [20, 20, 15, 5]
* simulate liquidating NFT 1: (20 eth)
  * Discounted Price = 20 x 0.95 = 19 eth
  * simulated CV = 60 - 19 = 41 eth
  * simulated TD = 50 - 19 = 31 eth
  * mark NFT 1 as liquidatable
  * simulated HF = 41 x 75 / 31 = 99
    -  99 < 110 => continue
* Simulate liquidating NFT 2: (20 eth)
  * Discounted Price = 20 x 0.95 = 19 eth
  * Simulated CV = 41 - 19 = 22 eth
  * Simulated TD = 31 - 19 = 12 eth
  * Mark NFT 2 as liquidatable
  * Simulated HF = 22 x 75 / 12 = 137
   - 137 > 110 => Stop liquidating additional NFTs
* NFTs to Liquidate = [NFT1, NFT2]
* NFTs Not to Liquidate = [NFT3, NFT4]
* Iterate through NFTs to Liquidate and list them in NftTrader
* Iterate through NFTs Not to Liquidate and delist them from NftTrader if they were previously placed there. 


---

# **Dynamic Recollateralization**

**Purpose:** To allow borrowers to have full custody over the state of the loan 
**Challenge:** Makes specific agreements harder to implement
**Solution:** Recollateralization or Decollateralization at any point during the loan given the health factor allows for it and have a universal loan agreement for the purpose of our project.

**Our Protocol:**
1. addCollateral: function allows the borrower to recollateralize at any point
    * by adding collateral, it will automatically:
      1. add it into there collateral profile
      2. update total collateral value
      3. update liquidity markings / trade listings if applicable
2. redeemCollateral: function allows the borrower to redeem there collateral in the case that they were over collateralized
    * required to have a health factor of at least 110 directly after simulating redemption in order to execute successfully.

~ ## **Example of recollateralizing** ~


---

# **Automatic and Flexible Loan Terms**

**Purpose:** To give the borrower flexibility on controlling when they wish to repay the loan.
**Challenge:** We need the pool to stay liquid so allowing long term loans will make the pool more static
**Solution:** a fixed initial interest rate added to borrowers debt and periodical interest added incentivizing them to pay off the loan as the borrowers health factore decreases and amount of debt increases, but still leaves it up to the borrower on how long or how short of a time they want to keep the loan

**Our Protocol:**
1. 10% flat interest on the initial loan amount 
2. 2% interest of total debt added to total debt every 30 days after the inital loan.
3. If the borrower wishes to borrow more money, and addition 10% will be added only on that amount they just borrowed. Currently, the 2% periodically added interest with the timestamp of the initial loan will be applied to this additional loan at the same time.

---

# NFT Pricing and Validation

**get_nft_price.py**

This system determines a fair market price for NFTs using data from the **Simplehash API**, which provides metadata and sales history for NFTs. The process includes validation, price calculation, and safety checks to ensure accuracy.

## Data Source Endpoints
- **General Metadata**: Includes collection details, token rarity, floor prices, and marketplace verification.
  - "https://api.simplehash.com/api/v0/nfts/ethereum/{contract_address}/{token_id}?include_attribute_percentages=1
- **Sales History**: Details past transactions, prices, and timestamps for individual NFTs.
  - "https://api.simplehash.com/api/v0/nfts/transfers/ethereum/{contract_address}/{token_id}?include_nft_details=0&only_sales=1&order_by=timestamp_desc&limit=50"
- **Current ETH/USD Exchange:** We access a NFTs sale history in USD due to it's greater stability. We utilized CoinGecko API.
  - "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"


## Pricing Protocol

1. **Data Retrieval**:
   - Load collection metadata and sales history from Simplehash API responses.
   - Load current ETH/USD exchange from Coingecko API response.

2. **Validation**:
    - Check if the NFT meets specific criteria (blockchain type, contract type, marketplace verification, and ownership distribution).
    - **Blockchain**: Must be on Ethereum.
    - **Contract**: Must be ERC721.
    - **Marketplaces**: Verified on at least one trusted platform (OpenSea, Blur, LooksRare).
    - **Ownership**: Must have at least 10 distinct owners.
    - **NSFW**: Collection must not be flagged as NSFW.

3. **Price Calculation**:
   - **Floor Price**: Average floor price across verified marketplaces (e.g., OpenSea, Blur, LooksRare).
   - **Sales History**: Time-weighted average of sales prices in USD, excluding outliers. Converted back to ETH
   - Combine valid prices to compute a fair market value.

4. **Decision on Pricing Basis**:
   - Use the floor price alone if the NFT has:
     - High rarity rank (rank > total NFTs / 2).
     - Low rarity score (< 1.0).
     - Low ownership distribution (< 20% unique ownership).
     - Sparse sales history (< 3 sales).

**Conclusion:** By leveraging verified data from the **Simplehash API**, this system combines robust validation with reliable pricing methods to produce accurate and safe valuations for NFTs.

---

# **Getting started with local hardhat environment:**


---

## Prerequisites:

1. Node.js and npm [installed](https://nodejs.org/en)
2. Get a free Coingecko api key
3. Get a free Simplehash api key

## Clone repo and install dependencies and create .env file
dynamic-NFT repository link: https://github.com/njdamstra/dynamic-NFT.git

```shell
git clone https://github.com/njdamstra/dynamic-NFT.git
cd dynamic-NFT
npm install ## installs dependencies like Hardhat, OpenZeppelin Contracts, Ether.js, dotenv, and more libraries
touch .env ## set up Environment Variables, make sure it is included in gitignore
```
### **.env contents:**
```shell
ETHERSCAN_API_KEY="______" # optional
ALCHEMY_API_KEY="_______" # optional
LOCAL_NODE_URL=http://127.0.0.1:8545 # needed
ALCHEMY_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY} # optional
DEPLOYER_PRIVATE_KEY="_______" # optional
SIMPLEHASH_API_KEY="_______" # needed
COINGECKO_DEMO_API_KEY="_______" # needed
```

--- 

# **Contracts Overview:**

---

* All contracts can be found in the 'contracts' directory.
* 'interfaces' directory contains the interfaces for these contracts.
* 'mock' directory contains MockOracle.sol contract and mockNft/ GoodNft.sol and badNft.sol which are ERC721 NFT collection contracts. These all serve for testing purposes.


## UserPortal

**Purpose:** central contract for lenders, borrowers, and liquidators interact with.

**Key functions for users to utilize:** 

// Lender functions:
* supply(amount);
* withdraw(amount);

// Borrower functions:
* addCollateral(collectionAddr, tokenId);
* borrow(amount);
* repay(amount);
* redeemCollateral(collectionAddr, tokenId);

// Liquidator functions:
* placeBid(collectionAddr, tokenId, amount);
* purchase(collectionAddr, tokenId, amount);

---

## CLendingPortal

**Purpose:** Manages and stores the ETH reserves pool where lenders and borrowers supply and borrow from, lenders interest allocation, and borrowers debt and interest rates.

**Responsibilities:**
  1. Allocate lenders interest
  2. Tracks total and net debt of borrowers
  3. Adds and collects interest from borrowers
  4. Holds and tracks pool balance
  5. Handles all lending and borrowing functions besides addCollateral and redeemCollateral from UserPortal.

---
## CCollateralManager

**Purpose:** Manages and stores the borrowers collateral in the borrowers collateral profile.

**Responsibilities:** 
  1. Keep track of borrowers health factor.
  2. Provides Total Collateral Value of a borrower.
  3. **Dynamic Liquidation:** Decides how to liquidate a borrowers collateral profile.
  4. Manages redemption of NFTs used as collateral and recollateralization.
  5. Handles addCollateral and redeemCollateral functions from UserPortal.

---
## NftValues

**Purpose:** Stores, provides, and requests values of relevant NFTs.
**Responsibilities:**
  1. Provide determined NFT prices to CollateralManager => getNftPrice(collectionAddr, tokenId)
  2. Tracks NFTs it needs to get regular price data for so that we don't exhaust the API.

### **Using Off Chain Oracles** 
**(for deployments to hardhat local networks and testnets)**

  3. Requests off chain data and new NFT collections and tokens through emitting events caught by our scripts: mockRequestPriceApi.js and requesetPriceApi.js
  4. Receives NFT price updates from off chain scripts: mockUpdatePriceApi.js and updatePriceApi.js

### **Using On Chain MockOracle Contract** 
**(for consistency and effieciency in testing)**

  5. NftValues calls MockOracle Contract to simulate making requests for prices
  6. Receives NFT price updates from MockOracle

**MockOracle:** used to manually set prices for NFTs in our tests files and update NftValues when we ask it to.

---
## NftTrader

**Purpose:** To simulate a bidding marketplace for NFTs listed by CollateralManager for liquidators to call place bids on and purchase after auction time period ends.

**Responsibilities:**

1. Track listings and auction status.
2. return money back to liquidator if lost bid.
3. Transfer NFT from CollateralManager to liquidator when purchased or auction ends.
4. send profits back to the pool and calls liquidate in LendingPool contract.
5. Allows CollateralManager to delist NFTs from the marketplace even if bids were already placed on it.


---
## CAddresses

**Purpose:** A registry of deployed contract addresses needed by our different contracts so that they can interact with each other.


---
# Testing Directory
---
* Contains the different test files we used to test our implementation
* We used hardhat ethers and chai expect in all of our test files

## Compile and Test Smart Contracts

```shell
npx hardhat compile ## Try to compile the contract. This will generate artifacts in the artifacts/ and cache/ directories.
npx hardhat test ## Tests are located in the test/ directory and are written using Mocha and Chai.
npx hardhat test test/basic.test.js ## for testing a specific test file
```

---

## basic.test

* Main testing file used when we were first testing our implementation

---

## attackScenarios.test




---

## edgecases.test

* Tests edge cases in our contracts

---

## normalScenarios.test

* Tests longer and more involved scenarios.

---

## oraclePricing.test

* Tests mockGet_nft_price.py which leverages the same algorithms as get_nft_price.py but uses predetermined data sets for consistent and predictable outputs to test functionality and edge cases of the algorithms in get_nft_price.py file.


---

# Scripts Overview

---

Used to deploy our contracts, interact with them off chain and send data from oracles.

### deploy.js

* deploy.js file is used to deploy the contract to Sepolia testnet.
  * This file has not been tested, but serves more as an example of how we would deploy it to testnets like sepolia and even ethereum mainnet!

---

## mockScript Directory

---

### mockDeploy.js

* Used to deploy and initialize our contracts on Localhost to run on our hardhat local network.
* Creates deployedAddresses.json with all of our different contract addresses
* Utilizes loadWallets.js and signers.json to keep track of the different hardhat public dummy accounts and there corresponding private key.

**Start the Local Hardhat Network**

```shell
npx hardhat compile ## compiles the contracts and updates their ABI's in artifacts
npx hardhat node ## starts running the local network, any commands following this must be in a new terminal
```

**Deploy and Initialize all the contracts on Hardhat Localhost**

```shell
npx hardhat run scripts/mockScript/mockDeploy.js --network localhost          
```

### runScenariosSetup.js

* An example of how to utilize deployedAddresses.json and signers.json files in our scripts as a shortcut for efficiency and organization

---

## mockOracles Directory

---

**Purpose:** used to interact with our contracts in testing and hardhat local network environments

### mockRequestPriceApi and mockUpdatePriceApi Files

**Purpose:** interacting oracles with our contracts when we deploy to Hardhat Localhost

**mockRequestPriceApi.js:**
 * Listens for NftValues contract to emit RequestNftPrice event when deployed.
 * Sends the collection address and token id of the requested NFT to get_nft_price.py (more on get_nft_price.py later) in order to get a calculated price for that NFT
 * Sends the price to NftValues by calling updateNft function in the NftValues contract

```shell
npx hardhat node
## now open a new terminal
npx hardhat run scripts/mockScript/mockDeploy.js --network localhost
npx hardhat run scripts/mockOracles/mockRequestPriceApi.js --network localhost
## open a 3rd terminal since this window is listening for events to be emitted
npx hardhat run scripts/testScript/mockRequestPriceApi.test.js --network localhost 
## look at it working in our 3 terminals!
npx hardhat run npx hardhat run scripts/testScript/mockGetNftPrice.test.js --network localhost
## outputs the price from NftValues!
```

---

**mockUpdatePriceApi.js:**
  * When ran externally, it gets all the pairs of collection addresses and token ids from NftValues by calling getNftAddrList() and getNftIdList()
  * Calculate there prices of each pair by using get_nft_price.py
  * Send it back to NftValues by calling updateNft function

```shell
npx hardhat node
## now open a new terminal
npx hardhat run scripts/mockScript/mockDeploy.js --network localhost

npx hardhat run scripts/testScript/mockRequestPriceApi.test.js --network localhost 

npx hardhat run scripts/mockOracles/mockUpdatePriceApi.js --network localhost

npx hardhat run npx hardhat run scripts/testScript/mockGetNftPrice.test.js --network localhost
## outputs the price from NftValues!
```

---

### mockGet_nft_price and Data Directory

**Purpose:** Simulate different API response scenarios by curating predetermined fake NFT data in the same format as what we'd get from Simplehash API data in order to test how get_nft_price.py would respond.

* Has the same algorithms as get_nft_price.py
* Instead of sending requests to Simplehash API for data, use sample responses found in the data directory. 
* Testing different example scenarios are tested in oraclePricing.test.js file

* Data folder has subfolders of different NFT names. (ex. nNft)
  * We use 2 different data sets for each NFT.
    * {collection_name}_general_{iteration}.json: Includes valuable such as floor prices that can change over time, that's why we included an iteration to showcase how floor prices could change and effect the NFTs valuation
      * Ex. nNft_general_1.json
    * {collection_name}_{tokenId}_sales.json: Includes data about past sales of that particular NFT Token. In our case, we don't have to iterate here since past sales shouldn't change once our contracts have custody over that NFT

```shell
npx hardhat test test/oraclePricing.test.js
```

---

## Oracles Directory:

---

**Purpose:**
* Illustrate examples of mockRequestPriceApi.js and mockUpdatePriceApi.js being used in a deployed testnet environment; requestPriceApi.js and updatePriceApi.js respectively
  * These have not been tested. Illustrative purposes only
* get_nft_price.py, however, is utilized by these scripts and there respective mock versions to calculate the price of a NFT.
* Uses Simplehash's API to query data on the collection of the NFT and sales history of the particular NFT token
  * Time Weighted Average of past sales serves as a boost of collaterals value above the collections floor price.
  * Security algorithm checks weather a particular NFT qualifies for this boost
    * Ex. onlyUseFloorPrice function
  * Prerequisite algorithm checks weather we have enough information on the NFT and checks for red flags to determine if our protocol will accept it as viable collateral. 
    * Ex. canAcceptNFT function




---

# Collaborators:

---

**Nathan Damstra:** Implementation leader

**Felix:** Bridge between researcher and implementation

**Sriman:** Final Report and Reacher

**Varun:** Final Report and Reacher

**Jonathan:** Final Report and Reacher





