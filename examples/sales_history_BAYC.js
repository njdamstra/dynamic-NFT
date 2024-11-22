const axios = require('axios')

// BAYC contract address
const address = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";
// const address2 = "NQSuAhlOs706-XBHAkbF6rbLJ50InHTj";

// Alchemy API Key
const apiKey = "iIkSSe8edm17Pauly052-RNIvxEam_Mg";
const tokenId = '4871';
const marketplace = 'seaport';

// Alchemy URL
const baseURL = `https://eth-mainnet.g.alchemy.com/nft/v2/${apiKey}`;
const url = `${baseURL}/getNFTSales/?contractAddress=${address}&tokenId=${tokenId}&marketplace=${marketplace}`;

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
