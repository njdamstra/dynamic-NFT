// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ICollateralManager {

    // list events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value);

    function isNftValid(address sender, address collection, uint256 tokenId) public view returns (bool);

    function getHealthFactor(address borrower) public returns (uint256);

    function getliquidatableCollateral(address borrower) public returns (Nft[]);

    function liquidateNft(address liquidator, address collectionAddress, uint256 tokenId) public payable;
}