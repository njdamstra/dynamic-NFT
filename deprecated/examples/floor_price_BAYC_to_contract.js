const axios = require('axios');
const hre = require('hardhat');

// BAYC contract address
const address = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";

// Alchemy API Key
const apiKey = "iIkSSe8edm17Pauly052-RNIvxEam_Mg";

// Alchemy URL
const baseURL = `https://eth-mainnet.g.alchemy.com/nft/v2/${apiKey}`;
const url = `${baseURL}/getFloorPrice/?contractAddress=${address}`;

const config = {
    method: 'get',
    url: url,
};

// Smart contract details
const contractAddress = "<Your_Contract_Address>";
const abi = [
    "function updateFloorPrice(uint256 _floorPrice) external"
];

// Private key and provider
const provider = hre.ethers.provider;
const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contract = new hre.ethers.Contract(contractAddress, abi, wallet);

// Fetch floor price and update the contract
axios(config)
    .then(async (response) => {
        const floorPriceETH = response.data.openSea.floorPrice;
        const floorPriceWei = hre.ethers.parseEther(floorPriceETH.toString());
        console.log(`Updating floor price to: ${floorPriceWei} wei`);

        const tx = await contract.updateFloorPrice(floorPriceWei);
        console.log("Transaction hash:", tx.hash);

        await tx.wait();
        console.log("Floor price updated successfully!");
    })
    .catch(error => console.error('Error fetching or updating floor price:', error));