// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {INftValues} from "../interfaces/INftValues.sol";


contract MockOracle {
    mapping(address => uint256) public floorPrices;
    mapping(address => bool) public safeCollections;

    address public nftValuesAddr;
    INftValues public iNftValues;
    address public owner;

    event SetCollection(address indexed collectionAddr, uint256 floorPrice, bool safe);
    event UpdateCollection(address indexed collectionAddr, uint256 newFloorPrice);
    event RequestFromNftValues(address indexed collectionAddr);
    event SentUpdateToNftValues(address indexed collectionAdd, uint256 floorPrice, bool safe);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }
    modifier onlyNftValues() {
        require(msg.sender == nftValuesAddr, "[*ERROR*] Only NftValues can call this function!");
        _;
    }

    function initialize(address _nftValuesAddr) external onlyOwner {
        nftValuesAddr = _nftValuesAddr;
        iNftValues = INftValues(nftValuesAddr);
    }

    // manually set the floor price for a collection;
    function manualUpdateFloorPrice(address collectionAddr, uint256 floorPrice) external onlyOwner {
        floorPrices[collectionAddr] = floorPrice;
        // updateAllFloorPrices();
        emit UpdateCollection(collectionAddr, floorPrice);
    }

    // manually set the floor price for a collection; this doesn't automatically update NftValues bc we're simulating how real oracles work
    function manualSetCollection(address collectionAddr, uint256 floorPrice, bool safe) external onlyOwner {
        floorPrices[collectionAddr] = floorPrice;
        safeCollections[collectionAddr] = safe;
        emit SetCollection(collectionAddr, floorPrice, safe);
    }

    // Get the floor price for a collection
    function getFloorPrice(address collectionAddr) external view returns (uint256) {
        return floorPrices[collectionAddr];
    }

    // updates all of NftValues collections floor price for collections who's floor price changed
    function updateAllFloorPrices() public {
        address[] memory collections = iNftValues.getCollectionAddrList();
        for (uint i = 0; i < collections.length; i++) {
            updateFloorPrice(collections[i]);
        }
    }

    // updates NftValues collection if its Floor Price changed
    function updateFloorPrice(address collectionAddr) public {
        if (floorPrices[collectionAddr] == 0 || iNftValues.getFloorPrice(collectionAddr) == floorPrices[collectionAddr]) {
            return; // nothing to update
        } else {
            iNftValues.updateFloorPrice(collectionAddr, floorPrices[collectionAddr]);
            emit SentUpdateToNftValues(collectionAddr, floorPrices[collectionAddr], safeCollections[collectionAddr]);
        }
    }

    // listens to NftValues if it requests Floor Price for a collection it needs info for
    function requestFloorPrice(address collectionAddr) external onlyNftValues {
        emit RequestFromNftValues(collectionAddr);
        if (floorPrices[collectionAddr] == 0 || !safeCollections[collectionAddr]) {
            iNftValues.updateCollection(collectionAddr, 0, false);
            emit SentUpdateToNftValues(collectionAddr, 0, false);
        } else {
            iNftValues.updateCollection(collectionAddr, floorPrices[collectionAddr], true);
            emit SentUpdateToNftValues(collectionAddr, floorPrices[collectionAddr], true);
        }
    }

    // function requestValidCollection(address collectionAddr) external onlyNftValues {
    //     if (floorPrices[collectionAddr] == 0 || !safeCollection[collectionAddr]) {
    //         return;
    //     }
    // }
}