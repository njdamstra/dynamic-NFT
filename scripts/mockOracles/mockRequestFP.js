require("dotenv").config();
const { loadWallets } = require("./loadWallets");
const deployedAddresses = require("./deployedAddresses.json");
const { ethers } = require("hardhat");


// Load wallets and provider
const wallets = loadWallets();
const deployer = wallets["deployer"]; // Use deployer wallet for updates
const provider = ethers.provider;

// Load contract ABI and address dynamically
const nftValuesABI = require("../artifacts/contracts/NftValues.sol/NftValues.json").abi;
const nftValuesAddress = deployedAddresses.NftValues;

// Create contract instance
const nftValuesContract = new ethers.Contract(nftValuesAddress, nftValuesABI, deployer);

// USAGE: If using off chain oracle, set initial mock floor prices and safe status for each Nft Collection:
const collectionMap = new Map();
collectionMap.set(deployedAddresses.GoodNft, [10, true]);
collectionMap.set(deployedAddresses.BadNft, [15, true]);

// Mock function to fetch or generate a floor price
async function fetchMockFloorPrice(collectionAddr) {
    // Optionally use pre-defined or random floor prices
    const floorPrice = collectionMap.get(collectionAddr)[0];
    console.log(`Mocked floor price for ${collectionAddr}: ${floorPrice} ETH`);
    return ethers.parseEther(floorPrice.toString()); // Convert to WEI
}
async function fetchMockSafety(collectionAddr) {
    if (collectionMap.has(collectionAddr)) {
        return collectionMap.get(collectionAddr)[1];
    } else {
        return false;
    }
}

// Listen for FloorPriceRequest events and handle them
async function listenForRequests() {
    console.log("Listening for RequestFloorPrice events...");

    nftValuesContract.on("RequestFloorPrice", async (collectionAddr) => {
        console.log(`Received RequestFloorPrice for Collection: ${collectionAddr}`);

        // Fetch the mock floor price
        const floorPrice = await fetchMockFloorPrice(collectionAddr);

        // Fetch the mock safe nft flag
        const safe = await fetchMockSafety(collectionAddr);
        console.log(`Mocked safe ranking for ${collectionAddr}: ${safe}`);
        // Update the floor price in the contract
        try {
            const tx = await nftValuesContract.updateCollection(collectionAddr, floorPrice, safe);
            console.log(`Floor price updated successfully! Transaction Hash: ${tx.hash}`);
        } catch (error) {
            console.error("Error updating floor price:", error.message);
        }
    });
}

// Start the script
listenForRequests().catch((error) => {
    console.error("Error starting listener:", error.message);
});