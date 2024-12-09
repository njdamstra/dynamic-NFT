require("dotenv").config();
const { ethers } = require("hardhat");
const deployedAddresses = require("../mockScript/deployedAddresses.json");
// const wallets = require("../mockScript/signers.json"); // Load named wallets from signers.json
const { loadWallets } = require("../mockScript/loadWallets");
const { exec } = require("child_process");

// Load wallets and provider
const wallets = loadWallets();
const deployer = wallets["deployer"]; // Use deployer wallet for updates
// Load environment variables
const CONTRACT_ADDRESS = deployedAddresses.NftValues;
const nftValuesABI = require("../../artifacts/contracts/NftValues.sol/NftValues.json").abi;

// Setup provider and signer
const provider = ethers.provider; // Use Hardhat's local provider

// const deployerWallet = new ethers.Wallet(wallets.find(w => w.name === "deployer").privateKey, provider);

// Load the contract ABI from Hardhat artifacts

const contract = new ethers.Contract(CONTRACT_ADDRESS, nftValuesABI, deployer);

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

// Function to update floor prices for all collections
async function updateFloorPrices() {
    console.log("Fetching collections from NftValues contract...");

    // Fetch the list of collections from NftValues
    try {
        const collections = await contract.getNftAddrList();
        const tokenIds = await contract.getNftIdList();
        console.log(`Found ${collections.length} NFTs.`);

        for (let i = 0; i < collections.length; i++) {

            const collection = collections[i];
            const tokenId = tokenIds[i];
            console.log(`Updating Collection: ${collection}, tokenId: ${tokenId}`);

            // Update the floor price in the contract
            try {
                const priceWei = await callPythonScript(collection, tokenId);
                console.log(`Price retrieved from Python script: ${priceWei}`);
                const tx = await contract.updateNft(collection, tokenId, priceWei);
                const receipt = await tx.wait();

                console.log("Transaction Receipt logs:");
                for (const log of receipt.logs) {
                    try {
                        const parsedLog = nftValues.interface.parseLog(log);
                        console.log("Event:", parsedLog.name);
                        console.log("Args:", parsedLog.args);
                    } catch (err) {
                        console.log("Unparsed log:", log);
                    }
                }
                console.log(`NFT price updated successfully! Transaction Hash: ${tx.hash}`);
            } catch (error) {
                console.error(`Error updating floor price for ${collection} ${tokenId}:`, error.message);
            }
        }
    } catch (error) {
        console.error("Error fetching NFTs for updating prices:", error.message);
    }
}

// Start the update process
updateFloorPrices().catch((error) => {
    console.error("Error in updateNft:", error.message);
});