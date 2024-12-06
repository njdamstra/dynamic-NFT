// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMockOracle {

    // Functions
    function initialize(address _nftValuesAddr) external;

    // function manualUpdateFloorPrice(address collectionAddr, uint256 floorPrice) external;

    // function manualSetCollection(
    //     address collectionAddr,
    //     uint256 floorPrice,
    //     bool safe
    // ) external;

    // function getFloorPrice(address collectionAddr) external view returns (uint256);

    // function updateAllFloorPrices() external;

    // function updateFloorPrice(address collectionAddr) external;

    // function requestFloorPrice(address collectionAddr) external;

    function manualUpdateNftPrice(address collectionAddr, uint256 tokenId, uint256 price) external;

    function getNftPrice(address collectionAddr, uint256 tokenId) external view returns (uint256);

    function updateAllNftPrices() external;

    function updateNftPrice(address collectionAddr, uint256 tokenId) external;

    function requestNftPrice(address collectionAddr, uint256 tokenId) external;
}