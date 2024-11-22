const { expect } = require("chai");
const hre = require("hardhat");

describe("NFTPricing Contract", function () {
    let NFTPricing, nftPricing, owner, addr1;

    beforeEach(async function () {
        NFTPricing = await hre.ethers.getContractFactory("NFTPricing");
        [owner, addr1] = await hre.ethers.getSigners();
        nftPricing = await NFTPricing.deploy();
        // await nftPricing.deployed();
        owner = (await hre.ethers.getSigners())[0];
        console.log("Contract address:", nftPricing.address);
    });

    it("Should set the owner correctly", async function () {
        expect(await nftPricing.owner()).to.equal(owner.address);
    });

    it("Should update the floor price when called by the owner", async function () {
        const newFloorPrice = hre.ethers.parseEther("1.0"); // 1 ETH
        await nftPricing.updateFloorPrice(newFloorPrice);

        expect(await nftPricing.floorPrice()).to.equal(newFloorPrice);
    });

    it("Should revert if a non-owner tries to update the floor price", async function () {
        const newFloorPrice = hre.ethers.parseEther("1.0");
        await expect(nftPricing.connect(addr1).updateFloorPrice(newFloorPrice))
            .to.be.revertedWith("Not authorized");
    });

    it("Should emit an event when the floor price is updated", async function () {
        const newFloorPrice = hre.ethers.parseEther("1.0");

        await expect(nftPricing.updateFloorPrice(newFloorPrice))
            .to.emit(nftPricing, "FloorPriceUpdated")
            .withArgs(newFloorPrice, await hre.ethers.provider.getBlock("latest").then((block) => block.timestamp));
    });
});
