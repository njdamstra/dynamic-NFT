const hre = require("hardhat");

async function main() {
  const NFTLoan = await hre.ethers.getContractFactory("NFTLoan");
  const nftLoan = await NFTLoan.deploy();

  await nftLoan.deployed();

  console.log("NFTLoan deployed to:", nftLoan.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
