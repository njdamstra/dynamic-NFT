// script to fetch the floor price from OpenSea from backend and update the smart contract
require("dotenv").config();
const { ethers } = require("ethers");
const axios = require("axios");
const hre = require("hardhat");

async function main() {
    // const provider = new ethers.providers.JsonRpcProvider(
    //     `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`
    // );
    const provider = hre.ethers.provider;
    const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

    const contractAddress = "<Your_Contract_Address>";
    const abi = [
        "function updateFloorPrice(uint256 _floorPrice) external",
    ];
    const contract = new hre.ethers.Contract(contractAddress, abi, wallet);

    const collectionSlug = "cryptopunks"; // Replace with your NFT collection slug
    const backendUrl = "http://localhost:3000/getFloorPrice";

    try {
        // Fetch floor price from the backend
        const response = await axios.post(backendUrl, { collectionSlug });

        console.log("Backend response:", response.data);
        if (!response.data.floorPrice) {
            console.error("Failed to fetch floor price from backend.");
            return;
        }

        const floorPrice = hre.ethers.parseEther(response.data.floorPrice.toString()); // convert to wei

        // Update the contract with the new floor price
        const tx = await contract.updateFloorPrice(floorPrice);
        console.log("Transaction hash:", tx.hash);

        await tx.wait();
        console.log("Floor price updated successfully!");
    } catch (error) {
        console.error("Error updating floor price:", error.message);
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
