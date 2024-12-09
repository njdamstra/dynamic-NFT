// alchemy-nft-api/axios-script.js
const axios = require('axios');

// Replace with your Alchemy API key:
const apiKey = "iIkSSe8edm17Pauly052-RNIvxEam_Mg";
const baseURL = `https://eth-mainnet.alchemyapi.io/v2/${apiKey}/getNFTs/`;
// Replace with the wallet address you want to query for NFTs:
// const ownerAddr = "0xF5FFF32CF83A1A614e15F25Ce55B0c0A6b5F8F2c";
const ownerAddr = "0x83205214543759c1Fde7bb0B98cBfC7fCb793294";

// Construct the axios request:
const config = {
  method: 'GET',
  url: `${baseURL}?owner=${ownerAddr}`
};

// Make the request and print the formatted response:
axios(config)
.then(response => console.log(
    JSON.stringify(response.data, null, 2)))
.catch(error => console.log(error));