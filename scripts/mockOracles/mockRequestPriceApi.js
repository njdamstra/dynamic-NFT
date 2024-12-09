require("dotenv").config();
const { loadWallets } = require("../mockScript/loadWallets");
const deployedAddresses = require("../mockScript/deployedAddresses.json");
const { ethers } = require("hardhat");
const { exec } = require("child_process");

// Load wallets and provider
const wallets = loadWallets();
const deployer = wallets["deployer"]; // Use deployer wallet for updates
const provider = ethers.provider;

// Load contract ABI and address dynamically
const nftValuesABI = require("../../artifacts/contracts/NftValues.sol/NftValues.json").abi;
const nftValuesAddress = deployedAddresses.NftValues;

// Create contract instance
const nftValuesContract = new ethers.Contract(nftValuesAddress, nftValuesABI, deployer);

async function fetchPastEvents() {
    const pastEvents = await nftValuesContract.queryFilter("RequestNftPrice");
    console.log("Past RequestNftPrice events:", pastEvents);
    for (const event of pastEvents) {
        const { collectionAddr, tokenId } = event.args;
        console.log(`Past Event - Collection: ${collectionAddr}, Token ID: ${tokenId}`);
    }
}

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


// Listen for FloorPriceRequest events and handle them
async function listenForRequests() {
    console.log("Provider network:", await provider.getNetwork());
    console.log("Listening for RequestNftPrice events...");
    fetchPastEvents();

    nftValuesContract.on("RequestNftPrice", async (collectionAddr, tokenId) => {
        console.log(`Received RequestNftPrice for Collection: ${collectionAddr}, TokenId: ${tokenId}`);
        try {
            // Fetch the mock floor price
            const priceWei = await callPythonScript(collectionAddr, tokenId);
            console.log(`NFT price retrieved from python script: ${priceWei}`);
            const tx = await nftValuesContract.updateNft(collectionAddr, tokenId, priceWei);
            const receipt = await tx.wait();
            console.log("Transaction Receipt logs:");
            console.log(receipt.log);
            console.log("now querying events!");
            const events = await nftValuesContract.queryFilter("NftPriceUpdated");
            console.log("Emitted events:", events);
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