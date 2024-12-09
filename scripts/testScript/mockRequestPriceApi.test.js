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

    console.log(`Requesting price for Collection: ${collection}, Token ID: ${tokenId}`);
    const tx = await nftValues.addNft(collection, tokenId); // .connect(deployer)
    const receipt = await tx.wait();

    console.log("Transaction Receipt logs:");
    for (const log of receipt.logs) {
        try {
            const parsedLog = nftValues.interface.parseLog(log);
            console.log("Event:", parsedLog.name);
            console.log("Args:", parsedLog.args);
        } catch (err) {
            console.log("Unparsed log:", log);
        }
    }

    console.log(`Price request transaction hash: ${tx.hash}`);
}

main().catch((error) => {
    console.error("Error:", error.message);
});
