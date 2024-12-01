// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract NftValues {
    address public owner;

    NftCollection[] public collectionList; // list of all active collections
    // Mapping to track the index of each collection in the array
    mapping(address => uint256) public collectionIndex;

    struct NftCollection {
        address collection; // NFT contract address or is it the same as collectionAddress?
        uint256 floorPrice;
    }

    // // lists of nfts we're keeping track of
    // struct Nft {
    //     address collection;
    //     uint256 tokenId;
    //     uint256 price;
    // }
    // Nft[] public nftList; // array of NFTs (Nft struct) being used as collateral
    // mapping(address => mapping(uint256 => uint256)) public nftIndex; // finds index of where the nft is stored in nftList

    // event DataRequest(address indexed collectionAddr, uint256 indexed tokenId);
    event RequestFloorPrice(address indexed collectionAddr);
    event FloorPriceUpdated(address indexed collection, uint256 newFloorPrice, uint256 timestamp);
    // event NftPriceUpdated(address indexed collection, uint256 indexed tokenId, uint256 newNftPrice, uint256 timestamp);
    event CollectionAdded(address indexed collectionAddr, uint256 floorPrice, uint256 timestamp);
    event CollectionRemoved(address indexed collectionAddr);
    // Events for tracking additions and removals
    // event NftAdded(address indexed collection, uint256 indexed tokenId);
    // event NftRemoved(address indexed collection, uint256 indexed tokenId);

    constructor() { //Is the owner not always CollateralManager? -F
        owner = msg.sender;
    }

    // Initialize function to set the CollateralManager address
    function initialize(address _collateralManagerAddr) external {
        require(owner == msg.sender, "Only the owner can call this function");
        require(_collateralManagerAddr != address(0), "Invalid address");
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

    // ** COLLECTIONLIST FUNCTIONS **


    function addCollection(address collectionAddr) external onlyOwner {
        require(collectionAddr != address(0), "Invalid collection address");
        if (collectionIndex[collectionAddr] != 0 && (
            collectionList.length != 0 || collectionList[collectionIndex[collectionAddr]].collection == collectionAddr
            )) {
                return; // collection already in list
            }
        // Add the new collection
        collectionList.push(NftCollection(collectionAddr, 0));
        collectionIndex[collectionAddr] = collectionList.length - 1; // Store the index of the collection
        //emit RequestFloorPrice(collectionAddr);
        //emit CollectionAdded(collectionAddr, floorPrice);
    }

    // Remove a collection from the list
    function removeCollection(address collectionAddr) external onlyOwner {
        require(collectionAddr != address(0), "Invalid collection address");
        uint256 index = collectionIndex[collectionAddr];
        require(index < collectionList.length, "Collection is not part of the list");

        // Ensure no NFTs from this collection are in collateralNfts (uncomment and implement logic if needed)
        // for (uint256 i = 0; i < collateralNfts.length; i++) {
        //     if (nftList[i].collection == collectionAddr) {
        //         revert("Cannot remove collection with active collateral NFTs");
        //     }
        // }

        // Move the last element into the place of the element to remove
        uint256 lastIndex = collectionList.length - 1;
        if (index != lastIndex) {
            NftCollection memory lastCollection = collectionList[lastIndex];
            collectionList[index] = lastCollection; // Overwrite the removed element with the last element
            collectionIndex[lastCollection.collection] = index; // Update the index of the moved element
        }

        // Remove the last element
        collectionList.pop();
        delete collectionIndex[collectionAddr]; // Delete the index mapping for the removed collection
        emit CollectionRemoved(collectionAddr);
    }


    function getCollectionList() public view returns (address[] memory) {
        address[] memory addresses = new address[](collectionList.length);
        for (uint256 i = 0; i < collectionList.length; i++) {
            addresses[i] = collectionList[i].collection;
        }
        return addresses;
    }

    function getCollection(address collection) public view returns (NftCollection memory) {
        require(collectionIndex[collection] < collectionList.length, "Collection does not exist");
        return collectionList[collectionIndex[collection]];
    }

    function getFloorPrice(address collection) public view returns (uint256) {
        return getCollection(collection).floorPrice;
    }

    // ** Floor Price off chain interactions **



    // Update the floor price of an existing collection
    function updateFloorPrice(address collectionAddr, uint256 newFloorPrice) external onlyOwner {
        require(collectionAddr != address(0), "Invalid collection address");
        uint256 index = collectionIndex[collectionAddr];
        if (index >= collectionList.length && collectionList[index].collection != collectionAddr) {
            return; // not in the list of collections
        }
        if (newFloorPrice <= 0) {
            return; // not a valid floor price (must be more than 0)
        }
        // Update the floor price
        collectionList[index].floorPrice = newFloorPrice;
        emit FloorPriceUpdated(collectionAddr, newFloorPrice, block.timestamp);
    }

    // TODO: emit an event that a script listens for to update floor price of a specific collection
    // function requestFloorPrice(address collection) internal {
    // }










    /////////////////// ** NFTLIST FUNCTIONS ** /////////////////////


    // // Add an NFT to the list
    // function addNft(address collection, uint256 tokenId) external onlyOwner {
    //     if (nftIndex[collection][tokenId] != 0 && (
    //         nftList.length != 0 || nftList[nftIndex[collection][tokenId]].collection == collection
    //         )) {
    //         return; // nft already on the list!
    //     }

    //     // Add the NFT to the array
    //     nftList.push(Nft(collection, tokenId));
    //     nftIndex[collection][tokenId] = nftList.length - 1; // Store the index of the NFT

    //     emit NftAdded(collection, tokenId);
    // }

    // // Remove an NFT from the list
    // function removeNft(address collection, uint256 tokenId) external onlyOwner {
    //     if (nftList.length <= 0) {
    //         return; // no NFTs to remove
    //     }
    //     uint256 index = nftIndex[collection][tokenId];
    //     if (nftList[index].collection != collection && nftList[index].tokenId != tokenId) {
    //         return; // NFT not found in list
    //     }
    //     // Move the last element into the place of the element to remove
    //     uint256 lastIndex = nftList.length - 1;
    //     if (index != lastIndex) {
    //         Nft memory lastNft = nftList[lastIndex];
    //         nftList[index] = lastNft; // Overwrite the removed element with the last element
    //         nftIndex[lastNft.collection][lastNft.tokenId] = index; // Update the index of the moved element
    //     }
    //     // Remove the last element
    //     nftList.pop();
    //     delete nftIndex[collection][tokenId]; // Delete the index mapping for the removed NFT
    //     emit NftRemoved(collection, tokenId);
    // }
    // // Get the full list of collateral NFTs (off-chain call)
    // function getNftList() external view returns (Nft[] memory) {
    //     return nftList;
    // }

    // function getNft(address collection, uint256 tokenId) public returns (memory Nft) {
    //     return nftList[nftIndex[collection][tokenId]];
    // }

    // // Update all NFT prices in a collection
    // function updatePrice(address collection, uint256 tokenId, uint256 newPrice) public onlyOwner {
    //     getNft(collection, tokenId).price = newPrice;
    // }

    // function getPrice(address collection, uint256 tokenId) public view {
    //     return getNft(collection, tokenId).price;
    // }

    // // Emit a data request event
    // function requestNftData(address collectionAddr, uint256 tokenId) external onlyOwner {
    //     emit DataRequest(collectionAddr, tokenId);
    // }

    // // Update the price of an NFT
    // function updateNftPrice(address collectionAddr, uint256 tokenId, uint256 price) external onlyOwner {
        
    //     getNft[collectionAddr][tokenId].price = price;
    //     // getNft[collectionAddr][tokenId].accept = accept;
    //     emit NftPriceUpdated(collectionAddr, tokenId, price, accept);
    // }

    // function isAcceptable(address collectionAddr, tokenId)



    // // TODO: logic on adjusting the price we evaluate the individual NFT to be if we want to analyse it beyond it's floor price
    // function nftPricingScheme(address collection, uint256 tokenId, uint256 oldPrice, uint256 floorPrice) external returns (uint256) {
    //     return floorPrice;
    // }

    // function getTokenIdPrice(address collection, uint256 tokenId) public view returns (uint256) {
    //     return nftCollections[collection].nftPrice[tokenId];
    // }





    // function getTokenIds(address collection) public view returns (uint256[]) {
    //     return nftCollections[collection].tokenIds;
    // }

    

    // // Add a token to a collection
    // function addTokenToCollection(address collection, uint256 tokenId, uint256 initialPrice) external onlyOwner {
    //     require(isCollectionPartOfList(collection), "[*ERROR*] Collection not found!");
    //     NftCollection storage nftCollection = nftCollections[collectionAddress];
    //     require(nftCollection.nftPrice[tokenId] == 0, "[*ERROR*] Token already added!");

    //     nftCollection.tokenIds.push(tokenId);
    //     nftCollection.nftPrice[tokenId] = initialPrice;

    // }

    // function getCollectionListLength() public view returns (uint) {
    //     return collectionsLength;
    // }

    // // Helper: Check if a collection is part of the list
    // function isCollectionPartOfList(address collection) public view returns (bool) {
    //     for (uint256 i = 0; i < collectionAddresses.length; i++) {
    //         if (collectionAddresses[i] == collection) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    // // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    // function checkCollection(address collection) public view returns (bool) {
    //     // For now, simply check if the collection is already added
    //     return isCollectionPartOfList(collection);
    // }

    // // TODO Placeholder for external contract checks (e.g., Alchemy integration)
    // function checkContract(address collection) public view returns (bool) {
    //     // Using Alchemy
    //     return false;
    // }
}