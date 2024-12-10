# Dynamic NFT Collateralization Protocol

# Getting started with local hardhat environment:

## Prerequisites:

1. Node.js and npm [installed](https://nodejs.org/en)
2. Get a free coingecko api key
3. Get a free simplehash api key

## Clone repo and install dependencies and create .env file
dynamic-NFT repository link: https://github.com/njdamstra/dynamic-NFT.git

```shell
git clone https://github.com/njdamstra/dynamic-NFT.git
cd dynamic-NFT
npm install // installs dependencies like Hardhat, OpenZeppelin Contracts, Ether.js, dotenv, and more libraries
touch .env // set up Environment Variables
```
** .env contents: **
```shell
ETHERSCAN_API_KEY="______" // optional
ALCHEMY_API_KEY="_______" // optional
LOCAL_NODE_URL=http://127.0.0.1:8545 // needed
ALCHEMY_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY} // optional
DEPLOYER_PRIVATE_KEY="_______"// optional
SIMPLEHASH_API_KEY="_______" // needed
COINGECKO_DEMO_API_KEY="_______" // needed
```

# Contracts Overview:

* All contracts can be found in the 'contracts' directory.
* 'interfaces' directory contains the interfaces for these contracts.
* 'mock' directory contains MockOracle.sol contract and mockNft/ GoodNft.sol and badNft.sol which are ERC721 NFT collection contracts. These all serve for testing purposes.

## UserPortal



## CLendingPortal



## CCollateralManager



## NftValues



## NftTrader



## CAddresses



# Testing Directory

* Contains the different test files we used to test our implementation
* We used hardhat ethers and chai expect in all of our test files

## Compile and Test Smart Contracts

```shell
npx hardhat compile ## Try to compile the contract. This will generate artifacts in the artifacts/ and cache/ directories.
npx hardhat test ## Tests are located in the test/ directory and are written using Mocha and Chai.
npx hardhat test test/basic.test.js ## for testing a specific test file
```

## basic.test



## attackScenarios.test



## edgecases.test



## normalScenarios.test



## oraclePricing.test



# Scripts Overview

* Used to deploy our contracts, interact with them off chain and send data from oracles.

### deploy.js

* deploy.js file is used to deploy the contract to Sepolia testnet.
  * This file has not been tested, but serves more as an example of how we would deploy it to testnets like sepolia and even ethereum mainnet!

## mockScript Directory

### mockDeploy.js

* Used to deploy and initialize our contracts on Localhost to run on our hardhat local network.
* Creates deployedAddresses.json with all of our different contract addresses
* Utilizes loadWallets.js and signers.json to keep track of the different hardhat public dummy accounts and there corresponding private key.

** Start the Local Hardhat Network **

```shell
npx hardhat compile ## compiles the contracts and updates their ABI's in artifacts
npx hardhat node ## starts running the local network, any commands following this must be in a new terminal
```

** Deploy and Initialize all the contracts on Hardhat Localhost **

```shell
npx hardhat run scripts/mockScript/mockDeploy.js --network localhost          
```

### runScenariosSetup.js

* An example of how to utilize deployedAddresses.json and signers.json files in our scripts as a shortcut for efficiency and organization

## mockOracles Directory

Purpose: used to interact with our contracts in testing and hardhat local network environments

### mockRequestPriceApi and mockUpdatePriceApi Files

Purpose: interacting oracles with our contracts when we deploy to Hardhat Localhost

* mockRequestPriceApi.js: 
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

* mockUpdatePriceApi.js:
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

### mockGet_nft_price and Data Directory

Purpose: Simulate different API response scenarios by curating predetermined fake NFT data in the same format as what we'd get from Simplehash API data in order to test how get_nft_price.py would respond.

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

## Oracles Directory:

Purpose:
* Illustrate examples of mockRequestPriceApi.js and mockUpdatePriceApi.js being used in a deployed testnet environment; requestPriceApi.js and updatePriceApi.js respectively
  * These have not been tested. Illustrative purposed only
* get_nft_price.py, however, is utilized by these scripts and there respective mock versions to calculate the price of a NFT.
* Uses Simplehash's API to query data on the collection of the NFT and sales history of the particular NFT token
  * Time Weighted Average of past sales serves as a boost of collaterals value above the collections floor price.
  * Security algorithm checks weather a particular NFT qualifies for this boost
    * Ex. onlyUseFloorPrice function
  * Prerequisite algorithm checks weather we have enough information on the NFT and checks for red flags to determine if our protocol will accept it as viable collateral. 
    * Ex. canAcceptNFT function





# NFT Pricing and Validation

** get_nft_price.py in depth **

This system determines a fair market price for NFTs using data from the **Simplehash API**, which provides metadata and sales history for NFTs. The process includes validation, price calculation, and safety checks to ensure accuracy.

---

## Data Sources
- **General Metadata**: Includes collection details, token rarity, floor prices, and marketplace verification.
- **Sales History**: Details past transactions, prices, and timestamps for individual NFTs.

---

## Pricing Process

1. **Data Retrieval**:
   - Load collection metadata and sales history from Simplehash API responses.

2. **Validation**:
   - Check if the NFT meets specific criteria (blockchain type, contract type, marketplace verification, and ownership distribution).

3. **Price Calculation**:
   - **Floor Price**: Average floor price across verified marketplaces (e.g., OpenSea, Blur, LooksRare).
   - **Sales History**: Time-weighted average of sales prices, excluding outliers.
   - Combine valid prices to compute a fair market value.

4. **Decision on Pricing Basis**:
   - Use the floor price alone if the NFT has:
     - High rarity rank (rank > total NFTs / 2).
     - Low rarity score (< 1.0).
     - Low ownership distribution (< 20% unique ownership).
     - Sparse sales history (< 3 sales).

---

## Validation Criteria

### **Acceptance Checks**
- **Blockchain**: Must be on Ethereum.
- **Contract**: Must be ERC721.
- **Marketplaces**: Verified on at least one trusted platform (OpenSea, Blur, LooksRare).
- **Ownership**: Must have at least 10 distinct owners.
- **NSFW**: Collection must not be flagged as NSFW.

### **Floor Price Decision**
- Rarity rank, score, ownership distribution, and sales history determine whether the floor price should be solely relied upon.

---

## Key Functions

### `getNftPrice(collection_name, token_id, iteration)`
Calculates the fair price of an NFT by combining the floor price and sales history, or using the floor price alone if necessary.

### `getFloorPrice(collection_data)`
Computes the average floor price across verified marketplaces.

### `getNftSalesPrice(sales_data)`
Calculates the time-weighted average sales price, excluding outliers based on interquartile range (IQR).
Uses USD value to account for Ether fluctuation

### `canAcceptNFT(sales_data, collection_data)`
Validates if the NFT meets the criteria for inclusion based on blockchain, contract, marketplace verification, and ownership distribution.

### `onlyUseFloorPrice(sales_data, collection_data)`
Determines if the floor price should be the sole basis for valuation based on rarity, ownership, and sales history.

---

## Conclusion
By leveraging verified data from the **Simplehash API**, this system combines robust validation with reliable pricing methods to produce accurate and safe valuations for NFTs.

---

# **Improvements:**

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
    - if health factor > 100; stop marking NFTs as liquidatable.
    - else repeat for the next NFT in borrowers collateral profile without restoring simulated total collateral and total debt value

4. Liquidating: list all the NFTs marked as liquidatable by adding it to a 24 hour auction in NftTrader. set the base price with a 5% discount of the oracle valuated price

5. Unliquidation: if in the 24 hour period: the nft values increases and restores the health factor above 100, the borrower repays enough or all of there debts, or provides additional collateral, the NFT will be delisted from NftTrader and be safe in the borrowers collateral profile. If there was no liquidators that placed a bid on it within the 24 hour period, the listing changes to a 'buyNow' state where any liquidator can purchase it immediately for it's base price, or it can be delisted for the same reasons mentioned earlier, which ever one comes first.


## **Example of Borrower Friendly Liquidation**

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
  * simulated HF = 41 x 75 / 31 = 99  """so close"""
* Simulate liquidating NFT 2: (20 eth)
  * Discounted Price = 20 x 0.95 = 19 eth
  * Simulated CV = 41 - 19 = 22 eth
  * Simulated TD = 31 - 19 = 12 eth
  * Mark NFT 2 as liquidatable
  * Simulated HF = 22 x 75 / 12 = 137
   - Stop liquidating additional NFTs
* NFTs to Liquidate = [NFT1, NFT2]
* NFTs Not to Liquidate = [NFT3, NFT4]
* Iterate through NFTs to Liquidate and list them in NftTrader
* Iterate through NFTs Not to Liquidate and delist them from NftTrader if they were previously placed there. 




# **Dynamic Recollateralization**

**Purpose:** Allow for borrowers to have full custody over the state of the loan 
**Problem Addressing:**
**Solution:** Recollateralization or Decollateralization at any point during the loan given the health factor allows for it

**Our Protocol:**
1. addCollateral function allows the borrower to recollateralize at any point
    * If 

## **Example of recollateralizing**



# **Automatic and Flexible Loan Terms**
TODO
## **Long Term Loans**


