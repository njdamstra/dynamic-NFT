require("dotenv").config();
const { ethers } = require("hardhat");

// Load environment variables
const LOCAL_NODE_URL = process.env.LOCAL_NODE_URL || "http://127.0.0.1:8545";
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

// Setup provider and signer
const provider = new ethers.JsonRpcProvider(LOCAL_NODE_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Load the contract ABI from Hardhat artifacts
const nftValuesABI = require("../artifacts/contracts/NftValues.sol/NftValues.json").abi;
const contract = new ethers.Contract(CONTRACT_ADDRESS, nftValuesABI, wallet);

// Mock function to generate or fetch floor price
async function fetchMockFloorPrice(collectionAddr) {
    const floorPrice = Math.floor(Math.random() * 10) + 1; // Random floor price between 1 and 10 ETH
    console.log(`Mocked floor price for ${collectionAddr}: ${floorPrice} ETH`);
    return ethers.parseEther(floorPrice.toString()); // Convert to WEI
}

// Function to update floor prices for all collections
async function updateFloorPrices() {
    console.log("Fetching collections from NftValues contract...");

    // Fetch the list of collections from NftValues
    try {
        const collections = await contract.getCollectionList();
        console.log(`Found ${collections.length} collections.`);

        for (const collection of collections) {
            console.log(`Updating floor price for Collection: ${collection}`);
            const floorPrice = await fetchMockFloorPrice(collection);

            // Update the floor price in the contract
            try {
                const tx = await contract.updateFloorPrice(collection, floorPrice); // Assuming tokenId = 0 for collection-level update
                console.log(`Floor price updated successfully for ${collection}! Transaction Hash: ${tx.hash}`);
            } catch (error) {
                console.error(`Error updating floor price for ${collection}:`, error.message);
            }
        }
    } catch (error) {
        console.error("Error fetching collections:", error.message);
    }
}

// Start the update process
updateFloorPrices().catch((error) => {
    console.error("Error in updateFloorPrices:", error.message);
});