// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
// smart contract to store NFT floor prices and allow an authorized account to update it.

contract NFTPricing {
    address public owner; // Address allowed to update the floor price
    uint256 public floorPrice; // Floor price in wei (e.g., 1 ETH = 1e18)

    event FloorPriceUpdated(uint256 newPrice, uint256 timestamp);

    constructor() {
        owner = msg.sender; // Deployer is the owner
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Function to update the floor price
    function updateFloorPrice(uint256 _floorPrice) external onlyOwner {
        floorPrice = _floorPrice;
        emit FloorPriceUpdated(_floorPrice, block.timestamp);
    }

    // Function to transfer ownership if needed
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
