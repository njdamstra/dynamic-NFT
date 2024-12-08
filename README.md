# Dynamic NFT Collateralization Protocal

# Getting started:

## Prerequisites:

1. Node.js and npm [installed](https://nodejs.org/en)

## Clone repo and install dependencies and create .env file
dynamic-NFT repository link: https://github.com/njdamstra/dynamic-NFT.git

```shell
git clone https://github.com/njdamstra/dynamic-NFT.git
cd dynamic-NFT
npm install // installs dependencies like Hardhat, OpenZeppelin Contracts, Ether.js, dotenv, and more libraries
touch .env // set up Environment Variables
```

# Testing

## Compile and Test Smart Contracts

```shell
npx hardhat compile // Try to compile the contract. This will generate artifacts in the artifacts/ and cache/ directories.
npx hardhat test // Tests are located in the test/ directory and are written using Mocha and Chai.
npx hardhat test test/basic.test.js // for testing a specific test file
```

# Hardhat local Network testing

1. in your terminal start a hardhat node:

```shell
npx hardhat node
```
* there should be a bunch of account addresses and there corresponding private keys

2. Open a new terminal window (keep the other one open and running npx hardhat node)

3. Deploy the deploy.js file to this local network

```shell
npx hardhat run scripts/deploy.js --network localhost
```
* this should return:
  * NFTPricing deployed to: _____
  * Deployer address: _____ (most likely 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)

4. cross reference the deployer address with the account addresses outputted by hardhat node.
   - Take note of its corresponding private key

5. go to examples/floor_price_local_deploy.js and update const privateKey and const contractAddress with the accounts private key and deployers address respectively
6. go to contracts/NFTPricing.sol and update hardhatAccount in the constructor with the deployer address
7. run floor_price_local_deploy.js

```shell
node floor_price_local_deploy.js
```

if everything works well, you should see floor price updated successfully!
* this means that we were able to update are contracts running on-chain with data from off-chain


# Oracles

## Chainlink
Use Chainlink price feeds to track the value of reserves
[Chainlinks Data Feed Doc](https://docs.chain.link/data-feeds)
1. install Chainlink Contracts
```angular2html
npm install @chainlink/contracts
```
2. Add the **AggregatorV3Interface** from Chainlink to our Solidity contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumer {
    AggregatorV3Interface internal priceFeed;

    // Constructor to set the price feed address
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
}
```
3. Set correct Price Feed Address:
   - For sepolia testnet use the following Chainlink price feeds:
     - ETH/USD: 0x694AA1769357215DE4FAC081bf1f309aDC325306
   - Pass these addresses when deploying the contract

4. Deploy and Test:
   - Deploy the contract to Sepolia
   - Call getLatestPrice to fetch the ETH/USD price

# Alchemy's API Oracles Tutorial

## How to use Alchemy's API generally:

### Alchemy SDK

1. Header of a js file
   - the right side of this function can import Network, initializeAlchemy, getNftsForOwner, getNftMetadata, BaseNft, NftTokenType
```js
const { Alchemy, Network } = require("alchemy-sdk");
```

2. Configure Alchemy SDK:
```js
const config = {
    apiKey: "your-api-key-from-alchemy",
    network: Network.ETH_MAINNET, // replace with your network?
};
```

3. Create the Alchemy object instance
```js
const alchemy = new Alchemy(config);
```

4. Create a function that'll run this code
```js
const ex_func = async () => {
    ...
}
```

5. Define the API's functions arguments in the function
```js
    const address = ____;
    const owner = ____;
    ...
```

6. Call the API function:
```js
    const response = await alchemy._API_LIB_._API_FUNC_(address, owner)
    // example
    const response = await alchemy.nft.getFloorPrice(address)
```

7. Log the response:
```js
    console.log(response) // logs entire response
    console.log(response.openSea) // logs response of NFT data only from openSea marketplace
```

8. Run the function by inluding *ex_func();* at bottom of the file or defines somewhere else:
```js
main();
```

9. test it out using node:
```
node file_name.js
```

### Axios
1. Header of a js file
```js
const axios = require("axios");
```

2. Define arguments for the API function along with your Alchemy API key:
```js
const apiKey = "your-api-key-from-alchemy"
const arg = ____;
...
```

3. Define base URL with the API library you want
```js
const baseURL = `https://eth-mainnet.g.alchemy.com/_API_LIB_/v2/${apiKey}`;
// example using nft lib:
const baseURL = `https://eth-mainnet.g.alchemy.com/nft/v2/${apiKey}`;
```

4. Finish the URL with the API function and the API function arguments as queries:
```js
const url = `${baseURL}/_API_FUNC_/?_ARG1_NAME_=${arg1}&_ARG2_NAME_=${arg2}`;
// example of getNFTSales
const url = `${baseURL}/getNFTSales/?contractAddress=${address}&tokenId=${tokenId}&marketplace=${marketplace}`;
```

5. Configure your input 
```js
const config = {
    method: 'get', // 'get' or 'post'
    url: url,
};
```

6. send the configured request using axios and print the response:
```js
axios(config)
    .then(response => {
        console.log(response['data'])
    }).catch(error => console.log('error', error));
```

7. test it out using node:
```
node file_name.js
```

## How to use the data from the responses in our smart contracts?

This data comes from off-chain sources and retrieves it through HTTPS requests.
This is not possible to do in smart contracts since they're on-chain and don't have access to the web
But there is a way to bridge this data so it can be used in our smart contracts

### Changing the JS files that retrieve the data so that it sends it to the smart contract

1. Add this additional header to our JS file:
```js
const hre = require('hardhat');
```

2. Add details about the smart contract that we are trying to send information to:
```js
const contractAddress = "<Our_Contract_Address>";
const abi = [
    "function _SMART_CONTRACT_FUNC_(arg_TYPE arg_NAME) _returns_and_other_func_headers"
];
// example
const abi = [
    "function updateFloorPrice(uint256 _floorPrice) external"
];
```

3. Create an instance of our contract:
```js
const provider = hre.ethers.provider;
const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contract = new hre.ethers.Contract(contractAddress, abi, wallet);
```

4. Update the contract with our response:

**alchemy-sdk**
```js
// in the ex_func put all current data into a try clause:
const ex_func = async () => {
    try {
        // retreive data like above ^^^^
        
        // get specific data we want to update our contracts with
        const parse_resp_data = response.____.____...;
        if (!parse_resp_data) {
            console.error("No ____ found");
            return;
        }
        // log specific data that's being used to update contract
        console.log("updating ____ to: ", parsed_resp_data);
        // call contract function that'll update it's available on-chain data
        const tx = await contract.update____(parsed_response_data);
        // log this "transaction" (its not rlly a transaction, just an update)
        console.log("Transaction hash:", tx.hash);
        
        await tx.wait();
        console.log("____ updated successfully!");
    }.catch (error) {
        console.error('Error fetching or updating ___:", error);
    }
};
// example with updating floor price:
const main = async () => {
    try {
        const address = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";
        const response = await alchemy.nft.getFloorPrice(address);
        console.log("Fetched floor price data:", response);
        // Extract OpenSea floor price
        const floorPriceETH = response.openSea.floorPrice;
        if (!floorPriceETH) {
            console.error("No floor price found for the collection.");
            return;
        }
        const floorPriceWei = hre.ethers.parseEther(floorPriceETH.toString());
        console.log(`Updating floor price to: ${floorPriceWei} wei`);
        const tx = await contract.updateFloorPrice(floorPriceWei);
        console.log("Transaction hash:", tx.hash);
        await tx.wait();
        console.log("Floor price updated successfully!");
    } catch (error) {
        console.error("Error fetching or updating floor price:", error);
    }
};
main();
```

**axios**

```js
axios(config)
    .then(async (response) => {
        const parsed_response_data = response.data.____.____...;
        // performing any necessary data type manipulation
        // log new data
        console.log("updating ___ to: ", parsed_response_data);
        // call contract function that'll update it's available on-chain data
        const tx = await contract.update____(parsed_response_data);
        // log this "transaction" (its not rlly a transaction, just an update)
        console.log("Transaction hash:", tx.hash);
        
        await tx.wait();
        console.log("____ updated successfully!");
    }).catch(error => console.error('Error fetching or updating ____:', error));
// example with floor price:
axios(config)
    .then(async (response) => {
        const floorPriceETH = response.data.openSea.floorPrice;
        const floorPriceWei = ethers.utils.parseEther(floorPriceETH.toString());
        console.log(`Updating floor price to: ${floorPriceWei} wei`);

        const tx = await contract.updateFloorPrice(floorPriceWei);
        console.log("Transaction hash:", tx.hash);

        await tx.wait();
        console.log("Floor price updated successfully!");
    })
    .catch(error => console.error('Error fetching or updating floor price:', error));
```


### Implementing smart contracts to retrieve this data:

include in our smart contract a way to update the data.

1. create an event:
```solidity
    event ____Updated(_data_type_ newData, uint256 timestamp);
    // example of floor price
    event FloorPriceUpdated(uint256 newPrice, uint256 timestamp);
```

2. Create a function that's only callable by the owner (us) of the contract that updates the data thru emitting the Update event:
```solidity
    function update____(_data_type_ _newData) external onlyOwner {
        data = _newData; // updates contract local variable 
        emit FloorPriceUpdated(_newData, block.timestamp);
    }
```



## All NFT methods defined in Alchemy:
[SDK NFT methods](https://docs.alchemy.com/reference/sdk-nft-methods)

### nft collection floor prices
[getFloorPrice](https://docs.alchemy.com/reference/getfloorprice-v3)
* returns the floor price of the specified NFT collection from **openSea** and **looksRare** marketplaces
* Example: floor_price_BAYC.js and run command 
  * https://{network}.g.alchemy.com/nft/v3/{apiKey}/getFloorPrice
```bash
node floor_price_BAYC.js
```

### nft sale history
[getNFTSales](https://docs.alchemy.com/reference/getnftsales-v3)
* retrieves NFT sales that have occurred through on-chain marketplaces
* Example: sales_history_BAYC.js
  * https://{network}.g.alchemy.com/nft/v3/{apiKey}/getNFTSales

### Information on client and there ownership of assets
[owner]
* given an address of a wallet, return metadata about there history and assets 
* can be useful to see if they own the NFT and how much of it they own and paid for
* Example: NFT_owner_info.js

## Prices of Currencies
[Token prices](https://docs.alchemy.com/reference/prices-api-quickstart)
* get prices of tokens (FT only i think) usually outputted in USD
* Example: fetch_prices_symbol.js and fetch_prices_address.js
  * "https://api.g.alchemy.com/prices/v1/{apiKey}/tokens/by-symbol"
  * "https://api.g.alchemy.com/prices/v1/{apiKey}/tokens/by-address"



## OpenSea
OpenSea provides an API for fetching NFT data
[OpenSea API Documentation](https://docs.opensea.io/reference/api-overview)
The challenge with OpenSea is that it is centralized and we have to bridge the data from off-chain to on-chain

**Common API Endpoints:**
* Fetch assets: /assets
* Fetch collections: /collections
* Fetch floor prices: /collection/{slug}

### Example API Call and Response:
API call in terminal:
```
curl -X GET "https://api.opensea.io/api/v1/collection/{collection_slug}" -H "Accept: application/json"
```
Response:
```json
{
  "collection": {
    "stats": {
      "floor_price": 1.2,
      "total_volume": 1234.56
    }
  }
}
```
* floor_price: floor price of the collection in ETH
* total_volume: Total trading volume for the collection




# Handling errors with npm installations caused by dependencies:

## General upstream dependency conflict error message for chai and hardhat-gas-reporter:

![Screenshot 2024-11-20 at 5.31.18 PM.png](..%2F..%2F..%2F..%2F..%2Fvar%2Ffolders%2Fmz%2F5hpg9g8501s0v7gh8_ns8_f00000gn%2FT%2FTemporaryItems%2FNSIRD_screencaptureui_sCKwIQ%2FScreenshot%202024-11-20%20at%205.31.18%E2%80%AFPM.png)
![Screenshot 2024-11-21 at 2.26.49 PM.png](..%2F..%2F..%2F..%2F..%2Fvar%2Ffolders%2Fmz%2F5hpg9g8501s0v7gh8_ns8_f00000gn%2FT%2FTemporaryItems%2FNSIRD_screencaptureui_Wlzmhh%2FScreenshot%202024-11-21%20at%202.26.49%E2%80%AFPM.png)
```
* npm error code ERESOLVE
* npm error ERESOLVE could not resolve
* npm error While resolving: _ROOT_USUALLY_IN_node_modules_/_PLUGIN_OR_DEPENDENCY_@_VERSION_ // has a requirement
  * While resolving: @nomicfoundation/hardhat-chai-matchers@2.0.8
  * While resolving: @nomicfoundation/hardhat-toolbox@5.0.0
* npm error Found: _DEPENDENCY@_CURR_VERSION_ // what's installed in our project
  * Found: chai@5.1.2
  * Found: hardhat-gas-reporter@2.2.1
* npm error Could not resolve dependency:
* npm error peer _DEPENDENCY@"^_NEEDED_VERSION_" from {While resolving:}
  * peer chai@"^4.2.0" from @nomicfoundation/hardhat-chai-matchers@2.0.8 // requires chai@^4.2.0
  * peer hardhat-gas-reporter@"^1.0.8" from @nomicfoundation/hardhat-toolbox@5.0.0 // requires hardhat-gas-reporter@^1.0.8
* npm error Conflicting peer dependency: _DEPENDENCY@_VERSION_
  * Conflicting peer dependency: chai@4.5.0
  * Conflicting peer dependency: hardhat-gas-reporter@1.0.10
* npm error Fix the upstream dependency conflict
```

### Summary of error:

Chai upstream dependency conflict: @nomicfoundation/hardhat-chai-matchers@2.0.8 requires chai@^4.2.0 who's parent is chai@4.5.0 but found chai@5.1.2

Gas report dependency conflict: @nomicfoundation/hardhat-toolbox@5.0.0 requires hardhat-gas-reporter@^1.0.8 who's parent is @1.0.10 but found: hardhat-gas-reporter@2.2.1

### Solution:

```shell
npm uninstall _DEPENDENCY_ // uninstall current version of the dependency
  * chai
  * hardhat-gas-reporter
npm install --save-dev _DEPENDENCY@^_REQUIRED_VERSION_ // install the correct dependency
  * chai@^4.2.0
  * hardhat-gas-reporter@^1.0.8
npm list _DEPENDENCY_ // verify installed versions (the parent is usually what'll get installed)
// If you're still running into issues:
rm -rf node_modules 
rm package-lock.json // remove both these folders 
npm install // install those folders again
// verify installed versions again
```



# What I've done so far:
Installed essential Packages:
1. Hardhat: npm install --save-dev hardhat
2. Ethers.js (for interacting with Ethereum): npm install --save-dev @nomiclabs/hardhat-ethers ethers
3. Dotenv (for environment variables): npm install dotenv

Set up Hardhat Project: npx hardhat --> sample JavaScript project

Set up .env file for Environment Variables

Set up Testing: npm install --save-dev mocha chai
- in each test file, include at the top: const { expect } = require("chai"); 

Installing additional dependencies as needed:
* OpenZeppelin contracts (provides secure smart contract templates): npm install @openzeppelin/contracts 
* Hardhat Plugins:
  * Hardhat-gas-report: npm install --save-dev hardhat-gas-reporter
  * solidity-coverage: npm install --save-dev solidity-coverage

Upgrading Plugins: npm install --save-dev _PLUGIN_NAME_/hardhat-upgrade (_PLUGIN_NAME_ = @openzeppelin)

Created a workflow in workflows/ci.yml using chatGPT which sets up Continuous Integration (CI)

Chainlink Ethereum Sepolia and added my metamask wallet address:
* [Chainlink Sepolia Faucet](https://faucets.chain.link/sepolia)
After obtaining Test ETH:
* npx hardhat run scripts/deploy.js --network sepolia
Verify contracts on Etherscan:
* npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS
Getting etherscan API key:
* [Etherscan doc](https://docs.etherscan.io)
  * Create an account, then get your API key
  * .env --> ETHERSCAN_API_KEY = ___
* Sepolia-specific API endpoint:
  * https://api-sepolia.etherscan.io/api

contract address:




# Protocol Contracts:

## Token Protocols:

### lolTokens (lenders token)
lolTokens are minted ERC20 token that are interest-bearing tokens that are minted and burned upon deposit and withdraw. The lolTokens value is pegged to the value of the corresponding deposited asset at a 1:1 ratio
All standard ERC20 methods are implemented (balanceOf(), transfer(), transferFrom(), approve(), totalSupply(), …

balanceOf() will always return the most up to data balance of the user including their principal balance + the interest generated by the principal balance


### xdToken (debt token)
xdTokens are interest-accuring tokens that are minted and burned on borrow and repay, representing the debt owed by the token holder
debtTokens are modeled on the ERC20 standard, but aren’t transferable so don’t implement any ERC20 func relating to transfer() and allowance().
balanceOf() ret accumulated debt of the user
totalSupply(): ret total debt accrued by all protocol users for debt token


### pretendNFT
ERC721 token representing the NFT used given to the borrower.

## Others

### LendPoolAddressProvider


# Using BendDAO 

```shell
npm install @benddao/bend-lending-protocol
```


## HARDHAT

Running 
```shell
$ npx hardhat
Hardhat version 2.9.9

Usage: hardhat [GLOBAL OPTIONS] <TASK> [TASK OPTIONS]

GLOBAL OPTIONS:

  --config              A Hardhat config file.
  --emoji               Use emoji in messages.
  --help                Shows this message, or a task's help if its name is provided
  --max-memory          The maximum amount of memory that Hardhat can use.
  --network             The network to connect to.
  --show-stack-traces   Show stack traces.
  --tsconfig            A TypeScript config file.
  --verbose             Enables Hardhat verbose logging
  --version             Shows hardhat's version.


AVAILABLE TASKS:

  check                 Check whatever you need
  clean                 Clears the cache and deletes all artifacts
  compile               Compiles the entire project, building all artifacts
  console               Opens a hardhat console
  coverage              Generates a code coverage report for tests
  flatten               Flattens and prints contracts and their dependencies
  help                  Prints this message
  node                  Starts a JSON-RPC server on top of Hardhat Network
  run                   Runs a user-defined script after compiling the project
  test                  Runs mocha tests
  typechain             Generate Typechain typings for compiled contracts
  verify                Verifies contract on Etherscan

To get help for a specific task run: npx hardhat help [task]
```


```shell
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost
npx hardhat console --network localhost
```











# Other Handy Resources:

* [OpenZeppelin Docs](https://docs.openzeppelin.com/contracts/4.x/)
* [Hardhat Docs](https://hardhat.org/hardhat-runner/docs/getting-started)
* [Implementing Chainlink Oracle Article](https://metana.io/blog/implementing-oracles-in-solidity/)
* 



