// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollateralManager {
    // Events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing, uint256 timestamp);
    event NFTDeListed(address indexed collection, uint256 tokenId, uint256 timestamp);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value, uint256 timestamp);
    event Liquidated(address indexed borrower, address indexed collectionAddress, uint256 tokenId, uint256 liquidated, uint256 timestamp);

    // Initialization
    function initialize(address _pool, address _nftTrader, address _nftValues) external;

    // Public/External Read Functions
    function isNftValid(address sender, address collection, uint256 tokenId) external view returns (bool);
    function getHealthFactor(address borrower) external returns (uint256);
    function getliquidatableCollateral(address borrower) external returns (address[] memory);
    function getCollateralValue(address borrower) external returns (uint256);
    function getBasePrice(address collection, uint256 tokenId) external returns (uint256);

    // Collateral Management
    function addCollateral(address collectionAddress, uint256 tokenId) external;
    function redeemCollateral(address borrower, address collectionAddress, uint256 tokenId) external;

    // Liquidation
    function liquidateNft(address borrower, address collectionAddress, uint256 tokenId, uint256 amount) external;
}