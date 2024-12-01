require("dotenv").config();
const { ethers } = require("hardhat");
const deployedAddresses = require("./deployedAddresses.json");
const wallets = require("./signers.json"); // Load named wallets from signers.json



// Load environment variables
const CONTRACT_ADDRESS = deployedAddresses.NftValues;
const nftValuesABI = require("../artifacts/contracts/NftValues.sol/NftValues.json").abi;

// Setup provider and signer
const provider = ethers.provider; // Use Hardhat's local provider

const deployerWallet = new ethers.Wallet(wallets.find(w => w.name === "deployer").privateKey, provider);

// Load the contract ABI from Hardhat artifacts

const contract = new ethers.Contract(CONTRACT_ADDRESS, nftValuesABI, deloyerWallet);

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