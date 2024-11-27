// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;
    // mapping(address => uint256) public collectionFloorPrice; // map nft collection address to its floor price in Eth or WEI
    // mapping(address => mapping(uint256 => uint256)) public nftValues; // map tokenId to our given value in Eth or WEI

    address[] public collectionAddresses; //renamed from collections -F
    uint public collectionsLength;

    mapping(address => NftCollection) public nftCollections; //renamed from collectionData -F

    struct NftCollection {
        address contractAddress; // NFT contract address
        string name;
        uint256 floorPrice;
        uint256[] collectionIds; // list of tokenIds used for this collection
        mapping(uint256 => uint256) nftPrice;
    }

    event FloorPriceUpdated(address collectionAddress, uint256 newFloorPrice, uint256 timestamp);
    event NftPriceUpdated(address collectionAddress, uint256 tokenId, uint256 newNftPrice, uint256 timestamp);

    constructor(address _owner) { //How do we get the owner? -F
        owner = _owner;
        collectionsLength = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }

    // Function to transfer ownership if needed
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // Function to update the floor price
    function updateFloorPrice(address collectionAddress, uint256 newFloorPrice) external onlyOwner {
        nftCollections[collectionAddress].floorPrice = newFloorPrice;
        emit FloorPriceUpdated(collectionAddress, newFloorPrice, block.timestamp);
        updateNftPrice(collectionAddress);
    }

    function updateNftPrice(address collectionAddress) external onlyOwner {
        NftCollection nftCollection = nftCollections[collectionAddress];
        uint256 floorPrice = nftCollection.floorPrice;
        uint256[] nftIds = nftCollection.collectionIds;
        mapping(uint256 => uint256) nftPrices = nftCollection.nftPrice; //why this mapping? -F

        // uint256 currPrice = nftValues[tokenId];
        uint i;
        uint256 nftId; // should we not use the nft address as it is unique? -F
        uint256 oldPrice;
        for (i = 0; i<nftIds.length; i++) {
            nftId = nftIds[i];
            oldPrice = nftPrices[nftId];
            nftPrices[nftId] = nftPricingScheme(collectionAddress, nftId, oldPrice, floorPrice);
            emit NftPriceUpdated(collectionAddress, nftId, nftPrices[nftId], block.timestamp);
        } 
        nftCollection.nftPrice = nftPrices;
        nftCollections[collectionAddress] = nftCollection;
    }

    // TODO: logic on adjusting the price we evaluate the individual NFT to be if we want to analyse it beyond it's floor price
    function nftPricingScheme(address collectionAddress, uint256 nftId, uint256 oldPrice, uint256 floorPrice) external returns (uint256) { // is nftId = tokenId?
        return floorPrice;
    }

    function getNftIdPrice(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        return nftCollections[collectionAddress].nftPrice[tokenId];
    }

    function getFloorPrice(address collectionAddress) public view returns (uint256) {
        return nftCollections[collectionAddress].floorPrice;
    }

    function getCollectionList() public view returns (address[]) {
        return collectionAddresses;
    }

    function getNftIds(address collectionAddress) public view returns (uint256[]) {
        return nftCollections[collectionAddress].collectionIds;
    }

    function addCollection(address collectionAddress) private {
        uint len = getCollectionListLength();
        if (isCollectionPartOfList(collectionAddress)) {
            return;
        } else if (checkCollection(collectionAddress)) { // what is checkCollection?
            collectionAddresses[len] = collectionAddress;
            collectionsLength += 1;
        }

    }

    function getCollectionListLength() public view returns (uint) {
        return collectionsLength;
    }

    function isCollectionPartOfList(address collectionAddress) public view returns (bool) {
        uint len = getCollectionListLength();
        for (uint i =0; i<len; i++) {
            if (collectionAddresses[i] == collectionAddress) {
                return true;
            }
        }
        return false;
    }

    // TODO: Check if contract is supported by Alchemy
    function checkContract(address contractAddress) public view returns (bool) {
        if (isCollectionPartOfList()) {
            return true;
        } else {
            // TODO: check if contract is supported by Alchemy
            // if yes, return true, else return false
        }

        return false;
    }
}