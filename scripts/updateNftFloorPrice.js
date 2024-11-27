require("dotenv").config();
const { Alchemy, Network } = require("alchemy-sdk");
const { ethers } = require("ethers");
const hre = require("hardhat");

// Alchemy SDK Config
const alchemyConfig = {
    apiKey: process.env.ALCHEMY_API_KEY,
    network: Network.ETH_MAINNET,
};
const alchemy = new Alchemy(alchemyConfig);

// Smart Contract Config
const contractAddress = process.env.NftValues_CONTRACT_ADDRESS; // Address of deployed NftValues.sol
const abi = [
    "function updateFloorPrice(uint256 tokenId, uint256 newFloorPrice) external",
    "function getCollectionList() public view returns (address[])",
    "function getCollectionListLength() public view returns (uint)"
];
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL); // Your Ethereum node provider
const privateKey = process.env.PRIVATE_KEY; // Private key of the contract owner
const wallet = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(contractAddress, abi, wallet);

// Array of NFTs to monitor (replace with actual token IDs)

// Function to fetch floor prices and update the contract
const updateFloorPrices = async () => {
    try {
        const collections = await contract.getCollectionList();
        console.log("Fetching floor prices...");

        for (const contractAddr of collections) {
            const response = await alchemy.nft.getFloorPrice(contractAddr);
            const floorPriceOS = response.openSea.floorPrice;
            const floorPriceLR = response.looksRare.floorPrice;

            if (!floorPriceOS) {
                console.log(`No floor price found for collection ${contractAddr} in OpenSea. Skipping.`);
                continue;
            }
            if (!floorPriceLR) {
                console.log(`No floor price found for collection ${contractAddr} in LooksRare. Skipping.`);
                continue;
            }

            const floorPriceAvg = (floorPriceLR + floorPriceOS) / 2;

            // const floorPriceWeiOS = ethers.utils.parseEther(floorPriceOS.toString());
            // const floorPriceWeiLR = ethers.utils.parseEther(floorPriceLR.toString());
            const floorPriceWeiAvg = ethers.utils.parseEther(floorPriceAvg.toString());
            console.log(`Updating floor price for collection ${contractAddr}: ${floorPriceWeiAvg.toString()} wei`);

            // Update the floor price in the smart contract
            const tx = await contract.updateFloorPrice(contractAddr, floorPriceWeiAvg);
            console.log(`Transaction sent: ${tx.hash}`);

            // Wait for the transaction to be mined
            await tx.wait();
            console.log(`Floor price updated for collection ${contractAddr}`);
        }
    } catch (error) {
        console.error("Error updating floor prices:", error);
    }
};

// Execute the update function
updateFloorPrices();
