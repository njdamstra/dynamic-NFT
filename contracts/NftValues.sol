// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;
    mapping(uint256 => uint256) public nftFloorPrices; // map tokenId to its floor price in Eth or WEI
    mapping(uint256 => uint256) public nftValues; // map tokenId to our given value in Eth or WEI

    event FloorPriceUpdated(uint256 tokenId, uint256 newFloorPrice, uint256 timestamp);
    event NftPriceUpdated(uint256 tokenId, uint256 newNftPrice, uint256 timestamp);

    constructor(address _owner) {
        owner = _owner
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }

     // Function to transfer ownership if needed
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // Function to update the floor price
    function updateFloorPrice(uint256 tokenId, uint256 newFloorPrice) external onlyOwner {
        nftFloorPrices[tokenId] = newFloorPrice;
        emit FloorPriceUpdated(tokenId, newFloorPrice, block.timestamp);
        updateNftPrice(tokenId);
    }

    function updateNftPrice(uint256 tokenId) external onlyOwner {
        floorPrice = nftFloorPrices[tokenId];
        currPrice = nftValues[tokenId];
        // TODO: logic on adjusting the price we evaluate the NFT to be if we want to analyse it beyond it's floor price


        updatedPrice = floorPrice;
        // END TODO
        emit NftPriceUpdated(tokenId, updatedPrice, block.timestamp);
    }

    function getNftIdPrice(uint256 tokenId) public (uint256) {
        return nftValues(tokenId);
    }

    function getNftIdFloorPrice(uint256 tokenId) public (uint256) {
        return nftFloorPrices(tokenId);
    }
}