// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface INftValues {
    // Struct Definitions
    struct NftCollection {
        address collection;
        uint256 floorPrice;
        bool safe;
        bool pending;
        bool notPending;
    }
    // Events
    event RequestFloorPrice(address indexed collectionAddr);
    event FloorPriceUpdated(address indexed collectionAddr, uint256 newFloorPrice, bool safe, uint256 timestamp);
    event CollectionAdded(address indexed collectionAddr, uint256 floorPrice, bool pending, uint256 timestamp);
    event CollectionRemoved(address indexed collectionAddr);

    // Public/External View Functions
    function owner() external view returns (address);
    function getCollectionList() external view returns (NftCollection[] memory);
    function getCollectionAddrList() external view returns (address[] memory);
    function getCollection(address collectionAddr) external view returns (address, uint256); // Returns collection address and floor price
    function getFloorPrice(address collectionAddr) external view returns (uint256);
    function collectionStatus(address collection) external view returns (uint);

    // Administrative Functions
    function initialize(bool _useOnChainOracle) external;

    function addCollection(address collectionAddr) external;
    function removeCollection(address collectionAddr) external;
    function requestOracleUpdates() external;
    function updateFloorPrice(address collectionAddr, uint256 newFloorPrice) external;
    function updateCollection(address collectionAddr, uint256 floorPrice, bool safe) external;
}