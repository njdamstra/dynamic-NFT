// prices-fetch-script.js
import fetch from 'node-fetch';

// Replace with your Alchemy API key:
const apiKey = "iIkSSe8edm17Pauly052-RNIvxEam_Mg";
const fetchURL = `https://api.g.alchemy.com/prices/v1/${apiKey}/tokens/by-address`;

// Define the network and contract addresses you want to fetch prices for.
const requestBody = {
  addresses: [
    {
      network: "eth-mainnet",
      address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" // USDC
    },
    {
      network: "eth-mainnet",
      address: "0xdac17f958d2ee523a2206206994597c13d831ec7" // USDT
    }
  ]
};

const requestOptions = {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${apiKey}`,
  },
  body: JSON.stringify(requestBody),
};

fetch(fetchURL, requestOptions)
  .then(response => response.json())
  .then(data => {
    console.log("Token Prices By Address:");
    console.log(JSON.stringify(data, null, 2));
  })
  .catch(error => console.error('Error:', error));
