// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface MockOracle {
    mapping(address => uint256) public floorPrices;

    // Functions
    function initialize(address _nftValuesAddr) external;

    function manualUpdateFloorPrice(address collectionAddr, uint256 floorPrice) external;

    function manualSetCollection(
        address collectionAddr,
        uint256 floorPrice,
        bool safe
    ) external;

    function getFloorPrice(address collectionAddr) external view returns (uint256);

    function updateAllFloorPrices() external;

    function updateFloorPrice(address collectionAddr) external;

    function requestFloorPrice(address collectionAddr) external;
}