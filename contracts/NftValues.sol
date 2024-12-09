// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IMockOracle} from "./interfaces/IMockOracle.sol";
import {IAddresses} from "./interfaces/IAddresses.sol";
import "hardhat/console.sol";
contract NftValues {
    address public owner;

    NftCollection[] public collectionList; // list of all active collections
    // Mapping to track the index of each collection in the array
    mapping(address => uint256) public collectionIndex;

    bool public useOnChainOracle;
    address public onChainOracle;
    IMockOracle public iOnChainOracle;
    address public collateralManagerAddr;

    address public addressesAddr;
    IAddresses public addresses;

    struct NftCollection {
        address collection; // NFT contract address or is it the same as collectionAddress?
        uint256 floorPrice;
        bool safe;
        bool pending;
        bool notPending;
    }

    // lists of nfts we're keeping track of
    struct Nft {
        address collection;
        uint256 tokenId;
        uint256 price;
        bool pending;
        bool notPending;
    }
    Nft[] public nftList; // array of NFTs (Nft struct) being used as collateral
    mapping(address => mapping(uint256 => uint256)) public nftIndex; // finds index of where the nft is stored in nftList
    mapping(address => mapping(uint256 => bool)) public nftIsMapping;

    // event DataRequest(address indexed collectionAddr, uint256 indexed tokenId);
    // event RequestFloorPrice(address indexed collectionAddr);
    // event FloorPriceUpdated(address indexed collection, uint256 newFloorPrice, bool safe, uint256 timestamp);
    // event CollectionAdded(address indexed collectionAddr, uint256 floorPrice, bool pending, uint256 timestamp);
    // event CollectionRemoved(address indexed collectionAddr);
    // Events for tracking additions and removals
    event NftAdded(address indexed collection, uint256 indexed tokenId, uint256 price, bool pending);
    event NftRemoved(address indexed collection, uint256 indexed tokenId);
    event NftPriceUpdated(address indexed collection, uint256 indexed tokenId, uint256 newNftPrice, uint256 timestamp);
    event RequestNftPrice(address indexed collection, uint256 indexed tokenId);

    constructor(address _addressesAddr) { //Is the owner not always CollateralManager? -F
        owner = msg.sender;
        addressesAddr = _addressesAddr;
        addresses = IAddresses(addressesAddr);
    }

    // Initialize function to set the CollateralManager address
    function initialize(bool _useOnChainOracle) external onlyOwner {
        onChainOracle = addresses.getAddress("MockOracle");
        collateralManagerAddr = addresses.getAddress("CollateralManager");
        useOnChainOracle = _useOnChainOracle;
        if (useOnChainOracle) {
            iOnChainOracle = IMockOracle(onChainOracle);
        } else {
            onChainOracle = address(0);
        }
        console.log("NftValues Initialized!");
        // collectionList.push(NftCollection(address(0), 0, false, false, true));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }

    modifier onlyCollateralManager() {
        require(msg.sender == collateralManagerAddr, "[*ERROR*] Only the Owner can call this function!");
        _;
    }

    // Function to transfer ownership if needed //if the owner is always the COllateral Manager, we do not need this function
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }










    /////////////////// ** NFTLIST FUNCTIONS ** /////////////////////

    // add modifer to prevent spam
    function addNft(address collectionAddr, uint256 tokenId) external {
        console.log("adding a NFT! Collection and tokenId:", collectionAddr, tokenId);
        require(collectionAddr != address(0), "Invalid collection address");
        if (nftIndex[collectionAddr][tokenId] != 0 && (
            nftList.length != 0 || nftList[nftIndex[collectionAddr][tokenId]].collection == collectionAddr
            )) {
                return; // collection already in list
            }
        if (nftList.length != 0) {
            if (nftList[0].collection == collectionAddr && nftList[0].tokenId == tokenId) {
                return; // collection already in list
            }
        }
        // Add the new collection
        nftList.push(Nft(collectionAddr, tokenId, 0, true, false));
        nftIndex[collectionAddr][tokenId] = nftList.length - 1; // Store the index of the collection
        console.log("nft at index:", nftIndex[collectionAddr][tokenId]);
        //emit RequestFloorPrice(collectionAddr);
        emit NftAdded(collectionAddr, tokenId, 0, true);
        if (useOnChainOracle) {
            requestOnChainNftPrice(collectionAddr, tokenId);
        } else {
            requestOffChainNftPrice(collectionAddr, tokenId);
        }
    }

    // Remove a collection from the list
    function removeNft(address collectionAddr, uint256 tokenId) external onlyCollateralManager {
        require(collectionAddr != address(0), "Invalid collection address");
        uint256 index = nftIndex[collectionAddr][tokenId];
        require(index < nftList.length, "Collection is not part of the list");

        // Move the last element into the place of the element to remove
        uint256 lastIndex = nftList.length - 1;
        if (index != lastIndex) {
            Nft memory lastNft = nftList[lastIndex];
            nftList[index] = lastNft; // Overwrite the removed element with the last element
            nftIndex[lastNft.collection][lastNft.tokenId] = index; // Update the index of the moved element
        }

        // Remove the last element
        nftList.pop();
        delete nftIndex[collectionAddr][tokenId]; // Delete the index mapping for the removed collection
        emit NftRemoved(collectionAddr, tokenId);
    }


    function getNftAddrList() public view returns (address[] memory) {
        address[] memory addresses = new address[](nftList.length);
        for (uint256 i = 0; i < nftList.length; i++) {
            addresses[i] = nftList[i].collection;
        }
        return addresses;
    }

    function getNftList() public view returns (Nft[] memory) {
        return nftList;
    }

    function getNftIdList() public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](nftList.length);
        for (uint256 i = 0; i < nftList.length; i++) {
            tokenIds[i] = nftList[i].tokenId;
        }
        return tokenIds;
    }

    function getNft(address collection, uint256 tokenId) public view returns (Nft memory) {
        require(nftIndex[collection][tokenId] < nftList.length, "Nft does not exist");
        return nftList[nftIndex[collection][tokenId]];
    }

    function getNftPrice(address collection, uint256 tokenId) public view returns (uint256) {
        uint256 price = getNft(collection, tokenId).price;
        console.log("getNftPrice called!", price);
        return price;
    }

    function nftStatus(address collection, uint256 tokenId) public view returns (uint) {
        Nft memory nft = getNft(collection, tokenId);
        if (nft.pending) {
            return 2; // pending oracle response for price and safety report
        } else if (!nft.pending && !nft.notPending) {
            return 3; // never requested so pending safety status
        } else if (!nft.pending && nft.price == 0) {
            return 0; // not pending and not safe
        } else {
            return 1; // not pending and safe to use.
        }
    }

    //// NFT ORACLE ///////

    function updateNft(address collectionAddr, uint256 tokenId, uint256 price) external {
        console.log("NftValues updateNft function called with price:", price);
        // require(msg.sender == owner || msg.sender == onChainOracle, "Don't have access rights to update Collection");
        require(collectionAddr != address(0), "Invalid collection address");
        console.log("nftIndex:", nftIndex[collectionAddr][tokenId]);
        Nft storage nft = nftList[nftIndex[collectionAddr][tokenId]];
        if (nft.collection == collectionAddr && nft.tokenId == tokenId) {
            nft.pending = false;
            nft.notPending = true;
            nft.price = price;
            emit NftPriceUpdated(collectionAddr, tokenId, price, block.timestamp);
        }
    }

    function requestNftOracleUpdates() public {
        // address[] memory collectionAddr = getNftList();
        for (uint i = 0; i < nftList.length; i++) {
            if (useOnChainOracle) {
                requestOnChainNftPrice(nftList[i].collection, nftList[i].tokenId);
            } else {
                requestOffChainNftPrice(nftList[i].collection, nftList[i].tokenId);
            }
        }
    }

    // request to update collections floor price of a specific collection using On Chain Oracle;
    function requestOnChainNftPrice(address collection, uint256 tokenId) internal {
        iOnChainOracle.requestNftPrice(collection, tokenId);
    }
    // emit an event that a script listens for to update floor price of a specific collection
    function requestOffChainNftPrice(address collection, uint256 tokenId) internal {
        console.log("Requesting off chain oracle for NFT price!");
        emit RequestNftPrice(collection, tokenId);
    }









        // ** COLLECTIONLIST FUNCTIONS **


    // function addCollection(address collectionAddr) external onlyCollateralManager {
    //     require(collectionAddr != address(0), "Invalid collection address");
    //     if (collectionIndex[collectionAddr] != 0 && (
    //         collectionList.length != 0 || collectionList[collectionIndex[collectionAddr]].collection == collectionAddr
    //         )) {
    //             return; // collection already in list
    //         }
    //     if (collectionList.length != 0) {
    //         if (collectionList[0].collection == collectionAddr) {
    //             return; // collection already in list
    //         }
    //     }
    //     // Add the new collection
    //     collectionList.push(NftCollection(collectionAddr, 0, true, true, false));
    //     collectionIndex[collectionAddr] = collectionList.length - 1; // Store the index of the collection
    //     //emit RequestFloorPrice(collectionAddr);
    //     emit CollectionAdded(collectionAddr, 0, true, block.timestamp);
    //     if (useOnChainOracle) {
    //         requestOnChainFloorPrice(collectionAddr);
    //     } else {
    //         requestOffChainFloorPrice(collectionAddr);
    //     }
    // }

    // // Remove a collection from the list
    // function removeCollection(address collectionAddr) external onlyCollateralManager {
    //     require(collectionAddr != address(0), "Invalid collection address");
    //     uint256 index = collectionIndex[collectionAddr];
    //     require(index < collectionList.length, "Collection is not part of the list");

    //     // Ensure no NFTs from this collection are in collateralNfts (uncomment and implement logic if needed)
    //     // for (uint256 i = 0; i < collateralNfts.length; i++) {
    //     //     if (nftList[i].collection == collectionAddr) {
    //     //         revert("Cannot remove collection with active collateral NFTs");
    //     //     }
    //     // }

    //     // Move the last element into the place of the element to remove
    //     uint256 lastIndex = collectionList.length - 1;
    //     if (index != lastIndex) {
    //         NftCollection memory lastCollection = collectionList[lastIndex];
    //         collectionList[index] = lastCollection; // Overwrite the removed element with the last element
    //         collectionIndex[lastCollection.collection] = index; // Update the index of the moved element
    //     }

    //     // Remove the last element
    //     collectionList.pop();
    //     delete collectionIndex[collectionAddr]; // Delete the index mapping for the removed collection
    //     emit CollectionRemoved(collectionAddr);
    // }


    // function getCollectionAddrList() public view returns (address[] memory) {
    //     address[] memory addresses = new address[](collectionList.length);
    //     for (uint256 i = 0; i < collectionList.length; i++) {
    //         addresses[i] = collectionList[i].collection;
    //     }
    //     return addresses;
    // }

    // function getCollectionList() public view returns (NftCollection[] memory) {
    //     return collectionList;
    // }

    // function getCollection(address collection) public view returns (NftCollection memory) {
    //     require(collectionIndex[collection] < collectionList.length, "Collection does not exist");
    //     return collectionList[collectionIndex[collection]];
    // }

    // function getFloorPrice(address collection) public view returns (uint256) {
    //     return getCollection(collection).floorPrice;
    // }

    // function collectionStatus(address collection) public view returns (uint) {
    //     NftCollection memory col = getCollection(collection);
    //     if (col.safe) {
    //         return 1; // safe and can be used
    //     } else if (col.pending) {
    //         return 2; // pending oracle response for price and safety report
    //     } else if (!col.pending && !col.notPending) {
    //         return 2; // never requested so pending safety status
    //     } else {
    //         return 0; // not pending and not safe
    //     }
    // }

    // // ** Floor Price off chain interactions **



    // // Update the floor price of an existing collection
    // function updateFloorPrice(address collectionAddr, uint256 newFloorPrice) external {
    //     require(msg.sender == owner || msg.sender == onChainOracle, "Don't have access rights to update Floor Price");
    //     require(collectionAddr != address(0), "Invalid collection address");
    //     uint256 index = collectionIndex[collectionAddr];
    //     if (index >= collectionList.length && collectionList[index].collection != collectionAddr) {
    //         return; // not in the list of collections
    //     }
    //     if (newFloorPrice < 0) {
    //         return; // not a valid floor price (must be more than 0)
    //     }
    //     // Update the floor price
    //     collectionList[index].floorPrice = newFloorPrice;
    //     emit FloorPriceUpdated(collectionAddr, newFloorPrice, collectionList[index].safe, block.timestamp);
    // }


    // function updateCollection(address collectionAddr, uint256 floorPrice, bool safe) external {
    //     require(msg.sender == owner || msg.sender == onChainOracle, "Don't have access rights to update Collection");
    //     require(collectionAddr != address(0), "Invalid collection address");
    //     NftCollection storage col = collectionList[collectionIndex[collectionAddr]];
    //     if (col.collection == collectionAddr) {
    //         col.pending = false;
    //         col.notPending = true;
    //         col.safe = safe;
    //         col.floorPrice = floorPrice;
    //         emit FloorPriceUpdated(collectionAddr, floorPrice, safe, block.timestamp);
    //     }
    // }

    // function requestOracleUpdates() public {
    //     address[] memory collectionAddr = getCollectionAddrList();
    //     for (uint i = 0; i < collectionAddr.length; i++) {
    //         if (useOnChainOracle) {
    //             requestOnChainFloorPrice(collectionAddr[i]);
    //         } else {
    //             requestOffChainFloorPrice(collectionAddr[i]);
    //         }
    //     }
    // }

    // // request to update collections floor price of a specific collection using On Chain Oracle;
    // function requestOnChainFloorPrice(address collection) internal {
    //     iOnChainOracle.requestFloorPrice(collection);
    // }
    // // emit an event that a script listens for to update floor price of a specific collection
    // function requestOffChainFloorPrice(address collection) internal {
    //     emit RequestFloorPrice(collection);
    // }
}