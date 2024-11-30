require("dotenv").config();
const hre = require("hardhat");
const { ethers } = require("ethers");

const LOCAL_NODE_URL = process.env.LOCAL_NODE_URL || "http://127.0.0.1:8545";
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

const provider = new ethers.JsonRpcProvider(LOCAL_NODE_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const nftValuesABI = require("../artifacts/contracts/NftValues.sol/NftValues.json").abi;

// Create contract instance
const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
const floorPrices = [10, 5, 8, 15, 20, 30, 1, 3];
index = 0;

// Mock function to generate or fetch floor price
async function fetchMockFloorPrice(collectionAddr) {
    // Simulate a random floor price in the range 1-10 ETH
    // const floorPrice = floorPrices[index];
    // index ++;
    const floorPrice = Math.floor(Math.random() * 10) + 1; // Random integer between 1 and 10
    console.log(`Mocked floor price for ${collectionAddr}: ${floorPrice} ETH`);
    return ethers.parseEther(floorPrice.toString()); // Convert to WEI
}

// Listen for FloorPriceRequest events and respond
async function listenForRequests() {
    console.log("Listening for FloorPriceRequest events...");

    contract.on("RequestFloorPrice", async (collectionAddr) => {
        console.log(`Received RequestFloorPrice for Collection: ${collectionAddr}`);

        // Fetch the mock floor price
        const floorPrice = await fetchMockFloorPrice(collectionAddr);

        // Update the floor price in the contract
        try {
            const tx = await contract.updateFloorPrice(collectionAddr, tokenId, floorPrice);
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