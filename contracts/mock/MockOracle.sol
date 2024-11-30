// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockOracle {
    mapping(address => uint256) public floorPrices;

    // Set the floor price for a collection
    function setFloorPrice(address collectionAddr, uint256 price) external {
        floorPrices[collectionAddr] = price;
    }

    // Get the floor price for a collection
    function getFloorPrice(address collectionAddr) external view returns (uint256) {
        return floorPrices[collectionAddr];
    }
}