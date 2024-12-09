// Imports Alchemy SDK and hardhat
const { Alchemy, Network } = require("alchemy-sdk");
const hre = require("hardhat");

// Mock Alchemy Config (You won't actually use it for local testing)
const alchemyConfig = {
    apiKey: process.env.ALCHEMY_API_KEY, // Alchemy SDK requires a key, but this won't be used for local testing
    network: Network.ETH_MAINNET,
};
const alchemy = new Alchemy(alchemyConfig);

// Account #19: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 (10000 ETH)
// Private Key: 0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e

// Local Hardhat Provider and Wallet
const provider = new hre.ethers.JsonRpcProvider("http://127.0.0.1:8545");
const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Use a private key from Hardhat node output account 0
const wallet = new hre.ethers.Wallet(privateKey, provider);

// Smart Contract Details
const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Use the address from your local deployment
const abi = [
    "function updateFloorPrice(uint256 _floorPrice) external",
    "function floorPrice() public view returns (uint256)",
];

// Connect to the deployed contract
const contract = new hre.ethers.Contract(contractAddress, abi, wallet);

// Mock function to simulate fetching a floor price
const mockGetFloorPrice = async () => {
    // Simulate the floor price in ETH (e.g., 12.345 ETH)
    return 12.345;
};

// Main function to test the update
const main = async () => {
    try {
        const address = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";
        // Fetch the floor price using Alchemy SDK
        const response = await alchemy.nft.getFloorPrice(address);
        console.log("Fetched floor price data:", response);

        // Extract OpenSea floor price
        const floorPriceETH = response.openSea.floorPrice;

        if (!floorPriceETH) {
            console.error("No floor price found for the collection.");
            return;
        }
        // Fetch the mock floor price
        // const floorPriceETH = await mockGetFloorPrice();
        console.log(`floor price fetched: ${floorPriceETH} ETH`);

        // Convert to wei
        const floorPriceWei = hre.ethers.parseEther(floorPriceETH.toString());
        console.log('floor price fetched in WEI:', floorPriceWei);

        // Update the contract with the floor price
        const tx = await contract.updateFloorPrice(floorPriceWei);
        console.log("Transaction hash:", tx.hash);

        // Wait for confirmation
        await tx.wait();
        console.log("Floor price updated successfully!");

        // Verify the updated floor price
        const updatedFloorPrice = await contract.floorPrice();
        console.log(`Updated floor price in contract: ${hre.ethers.formatEther(updatedFloorPrice)} ETH`);
    } catch (error) {
        console.error("Error during local testing:", error);
    }
};

main();
