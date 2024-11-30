// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface INftValues {
    // Events
    event RequestFloorPrice(address indexed collectionAddr);
    event FloorPriceUpdated(address indexed collectionAddr, uint256 newFloorPrice, uint256 timestamp);
    event CollectionAdded(address indexed collectionAddr, uint256 floorPrice, uint256 timestamp);
    event CollectionRemoved(address indexed collectionAddr);

    // Public/External View Functions
    function owner() external view returns (address);
    function getCollectionList() external view returns (address[] memory);
    function getCollection(address collectionAddr) external view returns (address, uint256); // Returns collection address and floor price
    function getFloorPrice(address collectionAddr) external view returns (uint256);

    // Administrative Functions
    function addCollection(address collectionAddr) external;
    function removeCollection(address collectionAddr) external;
    function updateFloorPrice(address collectionAddr, uint256 newFloorPrice) external;
}