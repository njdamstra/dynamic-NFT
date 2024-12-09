require("dotenv").config();
const { ethers } = require("hardhat");
const deployedAddresses = require("../../scripts/mockScript/deployedAddresses.json");
const nftValuesABI = require("../../artifacts/contracts/NftValues.sol/NftValues.json").abi;

async function main() {
    const [deployer] = await ethers.getSigners();
    const nftValues = new ethers.Contract(deployedAddresses.NftValues, nftValuesABI, deployer);

    // TEST THIS NFT
    const collection = "0xed5af388653567af2f388e6224dc7c4b3241c544";
    const tokenId = 4666;
    // END

    console.log(`Getting price for Collection: ${collection}, Token ID: ${tokenId} from NftValues`);
    const price = await nftValues.getNftPrice(collection, tokenId);
    // await price.wait();
    console.log(`got price from NftValues: ${price}`);
}

main().catch((error) => {
    console.error("Error:", error.message);
});
