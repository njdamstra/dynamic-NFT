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

// Mock floor prices for testing
const floorPrices = [10, 5, 8, 15, 20, 30, 1, 3];
let index = 0;

// Mock function to fetch or generate a floor price
async function fetchMockFloorPrice(collectionAddr) {
    // Optionally use pre-defined or random floor prices
    const floorPrice = floorPrices[index % floorPrices.length]; // Cycles through the mock prices
    index++;
    console.log(`Mocked floor price for ${collectionAddr}: ${floorPrice} ETH`);
    return ethers.parseEther(floorPrice.toString()); // Convert to WEI
}

// Listen for FloorPriceRequest events and handle them
async function listenForRequests() {
    console.log("Listening for RequestFloorPrice events...");

    nftValuesContract.on("RequestFloorPrice", async (collectionAddr) => {
        console.log(`Received RequestFloorPrice for Collection: ${collectionAddr}`);

        // Fetch the mock floor price
        const floorPrice = await fetchMockFloorPrice(collectionAddr);

        // Update the floor price in the contract
        try {
            const tx = await nftValuesContract.updateFloorPrice(collectionAddr, floorPrice);
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