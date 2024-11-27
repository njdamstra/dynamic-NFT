// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;
    // mapping(address => uint256) public collectionFloorPrice; // map nft collection address to its floor price in Eth or WEI
    // mapping(address => mapping(uint256 => uint256)) public nftValues; // map tokenId to our given value in Eth or WEI

    address[] public collections;

    mapping(address => NftCollection) public collectionData;

    struct NftCollection {
        address contractAddr; // NFT contract address
        string name;
        uint256 FloorPrice;
        uint256[] collectionIds; // list of tokenIds used for this collection
        mapping(uint256 => uint256) nftPrice;
    }


    event FloorPriceUpdated(address collection, uint256 newFloorPrice, uint256 timestamp);
    event NftPriceUpdated(address collectionAddr, uint256 tokenId, uint256 newNftPrice, uint256 timestamp);

    constructor(address _owner) {Z
        owner = _owner;
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
    function updateFloorPrice(address collection, uint256 newFloorPrice) external onlyOwner {
        collectionData[collection].floorPrice = newFloorPrice;
        emit FloorPriceUpdated(collection, newFloorPrice, block.timestamp);
        updateNftPrice(collection);
    }

    function updateNftPrice(address collection) external onlyOwner {
        NftCollection nftCollection = collectionData[collection];
        uint256 floorPrice = nftCollection.floorPrice;
        uint256[] nftIds = nftCollection.collectionIds;
        mapping(uint256 => uint256) nftPrices = nftCollection.nftPrice;

        // uint256 currPrice = nftValues[tokenId];
        uint i;
        uint256 nftId;
        uint256 oldPrice;
        for (i = 0; i<nftIds.length; i++) {
            nftId = nftIds[i];
            oldPrice = nftPrices[nftId]
            nftPrices[nftId] = nftPricingScheme(collection, nftId, oldPrice, floorPrice);
            emit NftPriceUpdated(collection, nftId, nftPrices[nftId], block.timestamp);
        } 
        nftCollection.nftPrice = nftPrices;
        collectionData[collection] = nftCollection;
        
    }

    // TODO: logic on adjusting the price we evaluate the individual NFT to be if we want to analyse it beyond it's floor price
    function nftPricingScheme(address collection, uint256 id, uint256 oldPrice, uint256 floorPrice) external returns (uint256) {
        return floorPrice;
    }

    function getNftIdPrice(address collection, uint256 tokenId) public view returns (uint256) {
        return collectionData[collection].nftPrice[tokenId];
    }

    function getFloorPrice(address collection) public view returns (uint256) {
        return collectionData[collection].floorPrice;
    }

    function getCollectionList() public view returns (address[]) {
        return collections;
    }

    function getNftIds(address collection) public view returns (uint256[]) {
        return collectionData[collection].collectionIds;
    }

    function addCollection(address collection) private {

    }
    function getCollectionListLength() public view returns (uint) {
        return collection.length;
    }
}