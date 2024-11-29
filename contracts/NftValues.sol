// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;

    address[] public collectionAddresses; //renamed from collections -F
    uint public collectionsLength;

    mapping(address => NftCollection) public nftCollections; //renamed from collectionData -F

    struct NftCollection {
        address collection; // NFT contract address or is it the same as collectionAddress?
        string name;
        uint256 floorPrice;
        uint256[] tokenIds; // list of tokenIds used for this collection //is tokeId = nftid? -F
        mapping(uint256 => uint256) nftPrice;
    }

    event FloorPriceUpdated(address indexed collection, uint256 newFloorPrice, uint256 timestamp);
    event NftPriceUpdated(address indexed collection, uint256 indexed tokenId, uint256 newNftPrice, uint256 timestamp);
    event CollectionAdded(address indexed collection, string name, uint256 timestamp);

    constructor() { //Is the owner not always CollateralManager? -F
        owner = msg.sender;
    }

    // Initialize function to set the CollateralManager address
    function initialize(address _collateralManagerAddr) external {
        require(owner == msg.sender, "Only the owner can call this function");
        require(_collateralManagerAddr != address(0), "Invalid address");
        collectionsLength = 0;
        owner = _collateralManagerAddr;
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
    function updateFloorPrice(address collection, uint256 newFloorPrice) external onlyOwner {
        require(isCollectionPartOfList(collection), "[*ERROR*] Collection not found!");
        require(newFloorPrice > 0, "[*ERROR*] Floor price must be positive!");

        nftCollections[collection].floorPrice = newFloorPrice;
        emit FloorPriceUpdated(collection, newFloorPrice, block.timestamp);

        updateNftPrices(collection);
    }

    // Update all NFT prices in a collection
    function updateNftPrices(address collection) public onlyOwner {
        NftCollection storage nftCollection = nftCollections[collection];
        uint256 floorPrice = nftCollection.floorPrice;

        for (uint256 i = 0; i < nftCollection.tokenIds.length; i++) {
            uint256 tokenId = nftCollection.tokenIds[i];
            uint256 oldPrice = nftCollection.nftPrice[tokenId];
            uint256 newPrice = nftPricingScheme(collection, tokenId, oldPrice, floorPrice);
            nftCollection.nftPrice[tokenId] = newPrice;

            emit NftPriceUpdated(collection, tokenId, newPrice, block.timestamp);
        }
    }


    // TODO: logic on adjusting the price we evaluate the individual NFT to be if we want to analyse it beyond it's floor price
    function nftPricingScheme(address collection, uint256 tokenId, uint256 oldPrice, uint256 floorPrice) external returns (uint256) {
        return floorPrice;
    }

    function getTokenIdPrice(address collection, uint256 tokenId) public view returns (uint256) {
        return nftCollections[collection].nftPrice[tokenId];
    }

    function getFloorPrice(address collection) public view returns (uint256) {
        return nftCollections[collection].floorPrice;
    }

    function getCollectionList() public view returns (address[]) {
        return collectionAddresses;
    }

    function getTokenIds(address collection) public view returns (uint256[]) {
        return nftCollections[collection].tokenIds;
    }

    // Function to add a new NFT collection
    function addCollection(address collection, string memory name, uint256 initialFloorPrice) external onlyOwner {
        require(!isCollectionPartOfList(collection), "[*ERROR*] Collection already added!");
        require(initialFloorPrice > 0, "[*ERROR*] Floor price must be positive!");

        // Initialize collection data
        NftCollection storage nftCollection = nftCollections[collection];
        nftCollection.collection = collection;
        nftCollection.name = name;
        nftCollection.floorPrice = initialFloorPrice;

        collectionAddresses.push(collection);
        collectionsLength += 1;

        emit CollectionAdded(collection, name, block.timestamp);
    }

    // Add a token to a collection
    function addTokenToCollection(address collection, uint256 tokenId, uint256 initialPrice) external onlyOwner {
        require(isCollectionPartOfList(collection), "[*ERROR*] Collection not found!");
        NftCollection storage nftCollection = nftCollections[collectionAddress];
        require(nftCollection.nftPrice[tokenId] == 0, "[*ERROR*] Token already added!");

        nftCollection.tokenIds.push(tokenId);
        nftCollection.nftPrice[tokenId] = initialPrice;

    }

    function getCollectionListLength() public view returns (uint) {
        return collectionsLength;
    }

    // Helper: Check if a collection is part of the list
    function isCollectionPartOfList(address collection) public view returns (bool) {
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            if (collectionAddresses[i] == collection) {
                return true;
            }
        }
        return false;
    }

    // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    function checkCollection(address collection) public view returns (bool) {
        // For now, simply check if the collection is already added
        return isCollectionPartOfList(collection);
    }

    // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    function checkContract(address collection) public view returns (bool) {
        // Using Alchemy
        return false;
    }
}