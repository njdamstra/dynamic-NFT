// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";

contract CollateralManager {
    mapping(address => mapping(uint256 => uint256)) public nftValues; // NFT values in ETH
    mapping(address => mapping(uint256 => bool)) public nftRegistered; // Whether an NFT is registered
    address public pool;

    constructor() {
        pool = msg.sender; // LendingPool is the owner
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Registers an NFT as collateral
    function registerNFT(address owner, uint256 nftId, uint256 value) external onlyPool {
        nftValues[owner][nftId] = value;
        nftRegistered[owner][nftId] = true;
    }

    // Checks if an NFT is registered as collateral
    function isCollateralRegistered(address owner, uint256 nftId) external view returns (bool) {
        return nftRegistered[owner][nftId];
    }

    // Retrieves the value of an NFT
    function getNFTValue(address owner, uint256 nftId) external view returns (uint256) {
        return nftValues[owner][nftId];
    }

    // Calculates the health factor for a user
    function getHealthFactor(address borrower, uint256 nftId) external view returns (uint256) {
        uint256 nftValue = nftValues[borrower][nftId];
        uint256 debt = LendingPool(pool).netBorrowedUsers(borrower);
        if (debt == 0) return type(uint256).max; // No debt means infinite health factor
        return (nftValue * 100) / debt;
    }

    // Dummy NFT liquidation function
    function liquidateNFT(address borrower, uint256 nftId) external onlyPool returns (uint256) {
        uint256 nftValue = nftValues[borrower][nftId];
        nftRegistered[borrower][nftId] = false; // Deregister the NFT
        nftValues[borrower][nftId] = 0; // Reset its value
        return nftValue; // Return ETH-equivalent value of the NFT
    }
}
