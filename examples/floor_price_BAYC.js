const axios = require('axios');

// BAYC contract address
const address = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";

// Alchemy API Key
const apiKey = "iIkSSe8edm17Pauly052-RNIvxEam_Mg"

// Alchemy URL
const baseURL = `https://eth-mainnet.g.alchemy.com/nft/v2/${apiKey}`;
const url = `${baseURL}/getFloorPrice/?contractAddress=${address}`;

const config = {
    method: 'get',
    url: url,
};

// Make the request and print the formatted response:
axios(config)
    .then(response => {
        console.log(response['data'])
    })
    .catch(error => console.log('error', error));