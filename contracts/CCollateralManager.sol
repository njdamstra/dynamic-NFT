// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";

contract CollateralManager {
    mapping(address => mapping(uint256 => uint256)) public nftValues; // NFT values in ETH
    mapping(uint256 => address) public nftOwners; // Tracks the owner of each unique NFT ID
    address public pool;

    constructor() {
        pool = msg.sender; // LendingPool is the owner
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Events for transparency
    event NFTRegistered(address indexed owner, uint256 indexed nftId, uint256 value);
    event NFTUpdated(address indexed owner, uint256 indexed nftId, uint256 newValue);
    event NFTLiquidated(address indexed borrower, uint256 indexed nftId, uint256 valueRecovered);

    // Registers an NFT as collateral
    function registerNFT(address owner, uint256 nftId, uint256 value) external onlyPool {
        require(nftValues[owner][nftId] == 0, "[*ERROR*] NFT already registered for this owner!");
        require(nftOwners[nftId] == address(0), "[*ERROR*] NFT already registered globally!");
        require(value > 0, "[*ERROR*] NFT value must be greater than 0!");

        nftValues[owner][nftId] = value;
        nftOwners[nftId] = owner; // Assign ownership globally
        emit NFTRegistered(owner, nftId, value);
    }

    // Updates the value of a registered NFT
    function updateNFTValue(address owner, uint256 nftId, uint256 newValue) external onlyPool {
        require(nftValues[owner][nftId] > 0, "[*ERROR*] NFT is not registered!");
        require(newValue > 0, "[*ERROR*] NFT value must be greater than 0!");

        nftValues[owner][nftId] = newValue;
        emit NFTUpdated(owner, nftId, newValue);
    }

    // Checks if an NFT is registered as collateral
    function isCollateralRegistered(address owner, uint256 nftId) external view returns (bool) {
        return nftValues[owner][nftId] > 0 && nftOwners[nftId] == owner;
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
        require(nftValue <= type(uint256).max / 100, "[*ERROR*] NFT value too high!");

        return (nftValue * 100) / debt;
    }

    // Dummy NFT liquidation function
    function liquidateNFT(address borrower, uint256 nftId) external onlyPool returns (uint256) {
        require(nftValues[borrower][nftId] > 0, "[*ERROR*] NFT is not registered!");
        require(nftOwners[nftId] == borrower, "[*ERROR*] Borrower does not own this NFT!");

        // Retrieve and delete the NFT value and ownership
        uint256 nftValue = nftValues[borrower][nftId];
        delete nftValues[borrower][nftId];
        delete nftOwners[nftId];

        emit NFTLiquidated(borrower, nftId, nftValue);
        return nftValue;
    }
}
