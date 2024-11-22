// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
// smart contract to store NFT floor prices and allow an authorized account to update it.

contract NFTPricing {
    address public owner; // Address allowed to update the floor price
    uint256 public floorPrice; // Floor price in wei (e.g., 1 ETH = 1e18)
    address public hardhatAccount;

    event FloorPriceUpdated(uint256 newPrice, uint256 timestamp);

    constructor() {
        owner = msg.sender; // Deployer is the owner
        hardhatAccount = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // account 0
    }

    modifier onlyOwner() {
        //console.log("owner: ", owner);

        require(msg.sender == owner || msg.sender == hardhatAccount, "Not authorized: ${owner}, ${msg.sender}");
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
