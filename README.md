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



# **Dynamic Liquidation Protocol**
TODO

## **Example of Borrower Friendly Liquidation**




# **Dynamic Recollateralization**
TODO
## **Example of recollateralizing**



# **Automatic and Flexible Loan Terms**
TODO
## **Long Term Loans**


