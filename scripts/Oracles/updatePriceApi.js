require("dotenv").config();
const { ethers } = require("ethers");
const { exec } = require("child_process");
const deployedAddresses = require("../deployedAddresses.json");

// Load Alchemy API key from environment variables
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
if (!ALCHEMY_API_KEY) {
    throw new Error("Alchemy API key is missing! Please set ALCHEMY_API_KEY in your .env file.");
}

// Sepolia network provider
const provider = new ethers.providers.AlchemyProvider("sepolia", ALCHEMY_API_KEY);

// Wallet setup
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;
if (!PRIVATE_KEY) {
    throw new Error("Deployer private key is missing! Please set DEPLOYER_PRIVATE_KEY in your .env file.");
}
const deployer = new ethers.Wallet(PRIVATE_KEY, provider);

// Load contract ABI and address dynamically
const nftValuesABI = require("../../artifacts/contracts/NftValues.sol/NftValues.json").abi;
const nftValuesAddress = deployedAddresses.NftValues;

// Create contract instance
const contract = new ethers.Contract(nftValuesAddress, nftValuesABI, deployer);

function callPythonScript(collectionAddr, tokenId) {
    return new Promise((resolve, reject) => {
        const pythonScriptPath = "scripts/Oracles/get_nft_price.py";
        const command = `python3 ${pythonScriptPath} ${collectionAddr} ${tokenId}`;

        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing Python script: ${error.message}`);
                reject(error);
                return;
            }
            if (stderr) {
                console.error(`Python script error output: ${stderr}`);
                reject(new Error(stderr));
                return;
            }
            // Convert the result to BigInt
            try {
                const priceWei = BigInt(stdout.trim());
                resolve(priceWei);
            } catch (err) {
                reject(new Error(`Invalid BigInt format: ${stdout.trim()}`));
            }
        });
    });
}

// Function to update floor prices for all NFTs
async function updateFloorPrices() {
    console.log("Fetching NFT collections and token IDs from NftValues contract...");

    try {
        const collections = await contract.getNftAddrList();
        const tokenIds = await contract.getNftIdList();
        console.log(`Found ${collections.length} NFTs.`);

        for (let i = 0; i < collections.length; i++) {
            const collection = collections[i];
            const tokenId = tokenIds[i];
            console.log(`Updating price for Collection: ${collection}, Token ID: ${tokenId}`);

            try {
                // Fetch the price using Python script
                const priceWei = await callPythonScript(collection, tokenId);
                console.log(`Price retrieved from Python script: ${priceWei}`);

                // Update the price in the contract
                const tx = await contract.updateNft(collection, tokenId, priceWei);
                const receipt = await tx.wait();

                console.log("Transaction Receipt logs:");
                for (const log of receipt.logs) {
                    try {
                        const parsedLog = contract.interface.parseLog(log);
                        console.log("Event:", parsedLog.name);
                        console.log("Args:", parsedLog.args);
                    } catch (err) {
                        console.log("Unparsed log:", log);
                    }
                }
                console.log(`NFT price updated successfully! Transaction Hash: ${tx.hash}`);
            } catch (error) {
                console.error(`Error updating price for Collection: ${collection}, Token ID: ${tokenId}`, error.message);
            }
        }
    } catch (error) {
        console.error("Error fetching NFTs or updating prices:", error.message);
    }
}

// Start the update process
updateFloorPrices().catch((error) => {
    console.error("Error in updateFloorPrices:", error.message);
});
