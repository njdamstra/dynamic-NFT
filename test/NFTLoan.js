const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTLoan Contract", function () {
  it("Should deploy the contract successfully", async function () {
    const NFTLoan = await ethers.getContractFactory("NFTLoan");
    const nftLoan = await NFTLoan.deploy();
    await nftLoan.deployed();

    expect(nftLoan.address).to.properAddress;
  });
});
