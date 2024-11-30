require("dotenv").config();
const Web3 = require("web3");
const axios = require("axios");

// Environment variables
const LOCAL_NODE_URL = process.env.LOCAL_NODE_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;

// Web3 setup
const web3 = new Web3(new Web3.providers.HttpProvider(LOCAL_NODE_URL));
const account = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY);
web3.eth.accounts.wallet.add(account);

// Contract ABI
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
        "name": "updateNftPrice",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
];

// Create contract instance
const contract = new web3.eth.Contract(CONTRACT_ABI, CONTRACT_ADDRESS);

// Function to fetch NFT price from Alchemy
async function fetchNftPrice(collectionAddr, tokenId) {
    const url = `https://eth-mainnet.g.alchemy.com/nft/v2/${ALCHEMY_API_KEY}/getFloorPrice/?contractAddress=${collectionAddr}`;
    try {
        const response = await axios.get(url);
        const floorPrice = response.data.openSea.floorPrice || 0; // Fallback to 0 if no floor price
        console.log(`Fetched floor price: ${floorPrice} ETH for Collection: ${collectionAddr}`);
        return floorPrice * 10 ** 18; // Convert to WEI for on-chain usage
    } catch (error) {
        console.error("Error fetching data from Alchemy:", error.message);
        return 0;
    }
}

// Function to send the NFT price back to the contract
async function updateNftPrice(collectionAddr, tokenId, price) {
    try {
        const tx = contract.methods.updateNftPrice(collectionAddr, tokenId, price);
        const gas = await tx.estimateGas({ from: account.address });
        const gasPrice = await web3.eth.getGasPrice();

        const txData = {
            from: account.address,
            to: CONTRACT_ADDRESS,
            data: tx.encodeABI(),
            gas,
            gasPrice
        };

        const signedTx = await web3.eth.accounts.signTransaction(txData, PRIVATE_KEY);
        const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
        console.log(`NFT price updated: Transaction Hash: ${receipt.transactionHash}`);
    } catch (error) {
        console.error("Error sending transaction:", error.message);
    }
}

// Listen to the DataRequest event
async function listenToEvents() {
    console.log("Listening for DataRequest events...");
    contract.events.DataRequest({}, async (error, event) => {
        if (error) {
            console.error("Error listening to events:", error.message);
            return;
        }

        const { collectionAddr, tokenId } = event.returnValues;
        console.log(`Data request received for Collection: ${collectionAddr}, Token ID: ${tokenId}`);

        // Fetch and update NFT price
        const price = await fetchNftPrice(collectionAddr, tokenId);
        if (price > 0) {
            await updateNftPrice(collectionAddr, tokenId, price);
        }
    });
}

// Start listening to events
listenToEvents();