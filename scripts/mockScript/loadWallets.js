const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

function loadWallets() {
    const signersPath = path.join(__dirname, "signers.json");

    // Read and parse the signer data
    const signersData = JSON.parse(fs.readFileSync(signersPath, "utf8"));

    // Map signers by name and construct wallets
    const provider = ethers.provider; // Use the Hardhat provider
    const wallets = {};
    signersData.forEach((signer) => {
        wallets[signer.name] = new ethers.Wallet(signer.privateKey, provider);
    });
    return wallets;
}

module.exports = { loadWallets };