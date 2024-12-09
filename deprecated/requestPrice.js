require("dotenv").config();
const hre = require("hardhat");
const { ethers } = require("ethers");
const { Alchemy, Network } = require("alchemy-sdk");
const { getSendTxParams } = require("web3-eth-contract");

// Environment variables
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const LOCAL_NODE_URL = process.env.LOCAL_NODE_URL;

// Hardhat setup
const provider = new hre.ethers.JsonRpcProvider(LOCAL_NODE_URL);
const wallet = new hre.ethers.Wallet(PRIVATE_KEY, provider);

// Alchemy setup
const alchemy = new Alchemy({
    apiKey: ALCHEMY_API_KEY,
    network: Network.ETH_MAINNET,
});

// Contract ABI (simplified)
const CONTRACT_ABI = [
    {
        "anonymous": false,
        "inputs": [
            { "indexed": false, "internalType": "address", "name": "collectionAddr", "type": "address" },
            { "indexed": false, "internalType": "uint256", "name": "tokenId", "type": "uint256" }
        ],
        "name": "DataRequest",
        "type": "event"
    },
    {
        "inputs": [
            { "internalType": "address", "name": "collectionAddr", "type": "address" },
            { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
            { "internalType": "uint256", "name": "price", "type": "uint256" }
        ],
        "name": "updateFloorPrice",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
];

// Create contract instance
const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

// Fetch floor price from Alchemy
async function fetchFloorPrice(collectionAddr) {
    try {
        const response = await alchemy.nft.getFloorPrice(collectionAddr);
        const floorPriceOS = response.openSea.floorPrice;
        const floorPriceLR = response.looksRare.floorPrice;

        if (!floorPriceOS) {
            console.log(`No floor price found for collection ${collectionAddr} in OpenSea. Skipping.`);
        }
        if (!floorPriceLR) {
            console.log(`No floor price found for collection ${collectionAddr} in LooksRare. Skipping.`);
        }

        const floorPriceAvg = (floorPriceLR + floorPriceOS) / 2;

        // const floorPriceWeiOS = ethers.utils.parseEther(floorPriceOS.toString());
        // const floorPriceWeiLR = ethers.utils.parseEther(floorPriceLR.toString());
        const floorPriceWeiAvg = ethers.utils.parseEther(floorPriceAvg.toString());
        console.log(`Updating floor price for collection ${collectionAddr}: ${floorPriceWeiAvg.toString()} wei`);
    } catch (error) {
        console.error("Error fetching floor price from Alchemy:", error.message);
        return 0;
    }
}

async function getValidity(collectionAddr) {
    try {
        const response = await alchemy.nft.isSpamContract(collectionAddr);
        const isSpam = response.isSpamContract || true;
        console.log("fetched isSpam: ${isSpam}");
        return isSpam;
    } catch (error) {
        console.error("error trying to fetch whether this collection is marked as spam or not", error.message);
        return true;
    }

}

// Listen for DataRequest events
async function listenToRequests() {
    console.log("Listening for DataRequest events...");

    contract.on("FloorPriceRequest", async (collectionAddr, tokenId) => {
        console.log(`Received request for Collection: ${collectionAddr}, Token ID: ${tokenId}`);

        // Fetch the floor price
        const floorPrice = await fetchFloorPrice(collectionAddr);

        if (floorPrice > 0) {
            // Call updateFloorPrice on the contract
            try {
                const tx = await contract.updateFloorPrice(collectionAddr, tokenId, floorPrice);
                console.log(`Floor price updated! Transaction Hash: ${tx.hash}`);
            } catch (error) {
                console.error("Error updating floor price:", error.message);
            }
        } else {
            console.log(`No valid floor price found for Collection: ${collectionAddr}`);
        }
    });
    contract.on("ValidCollectionRequest", async (collectionAddr) => {
        console.log('received request for validity on Collection: ${collectionAddr}');
        const isSpam = await getValidity(collectionAddr);
        try {
            const tx = await hre.contract.updateInvalidList(collectionAddr, tokenId, floorPrice);
            console.log(`Validity list updated! Transaction Hash: ${tx.hash}`);
        } catch (error) {
            console.error("Error updating validity list:", error.message);
        }
    });
}

// Start the script
listenToRequests().catch((error) => {
    console.error("Error starting listener:", error.message);
});