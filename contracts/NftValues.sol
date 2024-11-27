// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;

    address[] public collectionAddresses; //renamed from collections -F
    uint public collectionsLength;

    mapping(address => NftCollection) public nftCollections; //renamed from collectionData -F

    struct NftCollection {
        address contractAddress; // NFT contract address or is it the same as collectionAddress?
        string name;
        uint256 floorPrice;
        uint256[] tokenIds; // list of tokenIds used for this collection //is tokeId = nftid? -F
        mapping(uint256 => uint256) nftPrice;
    }

    event FloorPriceUpdated(address indexed collectionAddress, uint256 newFloorPrice, uint256 timestamp);
    event NftPriceUpdated(address indexed collectionAddress, uint256 indexed tokenId, uint256 newNftPrice, uint256 timestamp);
    event CollectionAdded(address indexed collectionAddress, string name, uint256 timestamp);

    constructor(address _owner) { //Is the owner not always CollateralManager? -F
        owner = _owner;
        collectionsLength = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }

    // Function to transfer ownership if needed //if the owner is always the COllateral Manager, we do not need this function
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // Update floor price of a collection
    function updateFloorPrice(address collectionAddress, uint256 newFloorPrice) external onlyOwner {
        require(isCollectionPartOfList(collectionAddress), "[*ERROR*] Collection not found!");
        require(newFloorPrice > 0, "[*ERROR*] Floor price must be positive!");

        nftCollections[collectionAddress].floorPrice = newFloorPrice;
        emit FloorPriceUpdated(collectionAddress, newFloorPrice, block.timestamp);

        updateNftPrices(collectionAddress);
    }

    // Update all NFT prices in a collection
    function updateNftPrices(address collectionAddress) public onlyOwner {
        NftCollection storage collection = nftCollections[collectionAddress];
        uint256 floorPrice = collection.floorPrice;

        for (uint256 i = 0; i < collection.tokenIds.length; i++) {
            uint256 tokenId = collection.tokenIds[i];
            uint256 oldPrice = collection.nftPrice[tokenId];
            uint256 newPrice = nftPricingScheme(collectionAddress, tokenId, oldPrice, floorPrice);
            collection.nftPrice[tokenId] = newPrice;

            emit NftPriceUpdated(collectionAddress, tokenId, newPrice, block.timestamp);
        }
    }


    // TODO: logic on adjusting the price we evaluate the individual NFT to be if we want to analyse it beyond it's floor price
    function nftPricingScheme(address collectionAddress, uint256 tokenId, uint256 oldPrice, uint256 floorPrice) external returns (uint256) {
        return floorPrice;
    }

    function getTokenIdPrice(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        return nftCollections[collectionAddress].nftPrice[tokenId];
    }

    function getFloorPrice(address collectionAddress) public view returns (uint256) {
        return nftCollections[collectionAddress].floorPrice;
    }

    function getCollectionList() public view returns (address[]) {
        return collectionAddresses;
    }

    function getTokenIds(address collectionAddress) public view returns (uint256[]) {
        return nftCollections[collectionAddress].tokenIds;
    }

    // Function to add a new NFT collection
    function addCollection(address collectionAddress, string memory name, uint256 initialFloorPrice) external onlyOwner {
        require(!isCollectionPartOfList(collectionAddress), "[*ERROR*] Collection already added!");
        require(initialFloorPrice > 0, "[*ERROR*] Floor price must be positive!");

        // Initialize collection data
        NftCollection storage collection = nftCollections[collectionAddress];
        collection.contractAddress = collectionAddress;
        collection.name = name;
        collection.floorPrice = initialFloorPrice;

        collectionAddresses.push(collectionAddress);
        collectionsLength += 1;

        emit CollectionAdded(collectionAddress, name, block.timestamp);
    }

    // Add a token to a collection
    function addTokenToCollection(address collectionAddress, uint256 tokenId, uint256 initialPrice) external onlyOwner {
        require(isCollectionPartOfList(collectionAddress), "[*ERROR*] Collection not found!");
        NftCollection storage collection = nftCollections[collectionAddress];
        require(collection.nftPrice[tokenId] == 0, "[*ERROR*] Token already added!");

        collection.tokenIds.push(tokenId);
        collection.nftPrice[tokenId] = initialPrice;

    }

    function getCollectionListLength() public view returns (uint) {
        return collectionsLength;
    }

    // Helper: Check if a collection is part of the list
    function isCollectionPartOfList(address collectionAddress) public view returns (bool) {
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            if (collectionAddresses[i] == collectionAddress) {
                return true;
            }
        }
        return false;
    }

    // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    function checkCollection(address collectionAddress) public view returns (bool) {
        // For now, simply check if the collection is already added
        return isCollectionPartOfList(collectionAddress);
    }

    // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    function checkContract(address contractAddress) public view returns (bool) {
        // Using Alchemy
        return false;
    }
}