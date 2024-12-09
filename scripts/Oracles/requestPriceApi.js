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
const nftValuesContract = new ethers.Contract(nftValuesAddress, nftValuesABI, deployer);

// Fetch past events from the blockchain
async function fetchPastEvents() {
    try {
        const pastEvents = await nftValuesContract.queryFilter("RequestNftPrice");
        console.log("Past RequestNftPrice events:", pastEvents);
        for (const event of pastEvents) {
            const { collectionAddr, tokenId } = event.args;
            console.log(`Past Event - Collection: ${collectionAddr}, Token ID: ${tokenId}`);
        }
    } catch (error) {
        console.error("Error fetching past events:", error.message);
    }
}

// Execute Python script to fetch NFT price
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

// Listen for RequestNftPrice events and handle them
async function listenForRequests() {
    console.log("Provider network:", await provider.getNetwork());
    console.log("Listening for RequestNftPrice events...");
    await fetchPastEvents();

    nftValuesContract.on("RequestNftPrice", async (collectionAddr, tokenId) => {
        console.log(`Received RequestNftPrice for Collection: ${collectionAddr}, TokenId: ${tokenId}`);
        try {
            // Fetch the price using Python script
            const priceWei = await callPythonScript(collectionAddr, tokenId);
            console.log(`NFT price retrieved from Python script: ${priceWei}`);
            
            // Update the contract with the retrieved price
            const tx = await nftValuesContract.updateNft(collectionAddr, tokenId, priceWei);
            const receipt = await tx.wait();
            console.log("Transaction Receipt logs:");
            for (const log of receipt.logs) {
                try {
                    const parsedLog = nftValuesContract.interface.parseLog(log);
                    console.log("Event:", parsedLog.name);
                    console.log("Args:", parsedLog.args);
                } catch (err) {
                    console.log("Unparsed log:", log);
                }
            }
            console.log(`NFT price updated successfully! Transaction Hash: ${tx.hash}`);
        } catch (error) {
            console.error("Error updating NFT price:", error.message);
        }
    });
}

// Start the script
listenForRequests().catch((error) => {
    console.error("Error starting listener:", error.message);
});
