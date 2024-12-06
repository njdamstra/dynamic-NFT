// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {INftValues} from "../interfaces/INftValues.sol";
import {IAddresses} from "../interfaces/IAddresses.sol";


contract MockOracle {
    mapping(address => uint256) public floorPrices;
    mapping(address => bool) public safeCollections;

    struct Nft {
        address collection;
        uint256 tokenId;
        uint256 price;
        bool pending;
        bool notPending;
    }

    mapping(address => mapping(uint256 => uint256)) public nftPrices;

    address public nftValuesAddr;
    INftValues public iNftValues;
    address public owner;

    address public addressesAddr;
    IAddresses public addresses;

    event UpdateCollection(address indexed collectionAddr, uint256 newFloorPrice);
    event UpdateNft(address indexed collectionAddr, uint256 tokenId, uint256 newPrice);
    event RequestFromNftValues(address indexed collectionAddr, uint256 indexed tokenId);
    event SentUpdateToNftValues(address indexed collectionAdd, uint256 tokenId, uint256 price);

    constructor(address _addressesAddr) {
        owner = msg.sender;
        addressesAddr = _addressesAddr;
        addresses = IAddresses(addressesAddr);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the Owner can call this function!");
        _;
    }
    modifier onlyNftValues() {
        require(msg.sender == nftValuesAddr, "[*ERROR*] Only NftValues can call this function!");
        _;
    }

    function initialize() external onlyOwner {
        nftValuesAddr = addresses.getAddress("NftValues");
        iNftValues = INftValues(nftValuesAddr);
    }

    // // manually set the floor price for a collection;
    // function manualUpdateFloorPrice(address collectionAddr, uint256 floorPrice) external onlyOwner {
    //     floorPrices[collectionAddr] = floorPrice;
    //     // updateAllFloorPrices();
    //     emit UpdateCollection(collectionAddr, floorPrice);
    // }

    // // manually set the floor price for a collection; this doesn't automatically update NftValues bc we're simulating how real oracles work
    // function manualSetCollection(address collectionAddr, uint256 floorPrice, bool safe) external onlyOwner {
    //     floorPrices[collectionAddr] = floorPrice;
    //     safeCollections[collectionAddr] = safe;
    //     emit SetCollection(collectionAddr, floorPrice, safe);
    // }

    // // Get the floor price for a collection
    // function getFloorPrice(address collectionAddr) external view returns (uint256) {
    //     return floorPrices[collectionAddr];
    // }

    // // updates all of NftValues collections floor price for collections who's floor price changed
    // function updateAllFloorPrices() public {
    //     address[] memory collections = iNftValues.getCollectionAddrList();
    //     for (uint i = 0; i < collections.length; i++) {
    //         updateFloorPrice(collections[i]);
    //     }
    // }

    // // updates NftValues collection if its Floor Price changed
    // function updateFloorPrice(address collectionAddr) public {
    //     if (floorPrices[collectionAddr] == 0 || iNftValues.getFloorPrice(collectionAddr) == floorPrices[collectionAddr]) {
    //         return; // nothing to update
    //     } else {
    //         iNftValues.updateFloorPrice(collectionAddr, floorPrices[collectionAddr]);
    //         emit SentUpdateToNftValues(collectionAddr, floorPrices[collectionAddr], safeCollections[collectionAddr]);
    //     }
    // }

    // // listens to NftValues if it requests Floor Price for a collection it needs info for
    // function requestFloorPrice(address collectionAddr) external onlyNftValues {
    //     emit RequestFromNftValues(collectionAddr);
    //     if (floorPrices[collectionAddr] == 0 || !safeCollections[collectionAddr]) {
    //         iNftValues.updateCollection(collectionAddr, 0, false);
    //         emit SentUpdateToNftValues(collectionAddr, 0, false);
    //     } else {
    //         iNftValues.updateCollection(collectionAddr, floorPrices[collectionAddr], true);
    //         emit SentUpdateToNftValues(collectionAddr, floorPrices[collectionAddr], true);
    //     }
    // }

    // function requestValidCollection(address collectionAddr) external onlyNftValues {
    //     if (floorPrices[collectionAddr] == 0 || !safeCollection[collectionAddr]) {
    //         return;
    //     }
    // }

    // manually set the floor price for a collection;
    function manualUpdateNftPrice(address collectionAddr, uint256 tokenId, uint256 price) external onlyOwner {
        nftPrices[collectionAddr][tokenId] = price;
        // updateAllFloorPrices();
        emit UpdateNft(collectionAddr, tokenId, price);
    }

    // Get the floor price for a collection
    function getNftPrice(address collectionAddr, uint256 tokenId) external view returns (uint256) {
        return nftPrices[collectionAddr][tokenId];
    }

    // updates all of NftValues collections floor price for collections who's floor price changed
    function updateAllFloorPrices() public {
        address[] memory addresses = iNftValues.getNftAddrList();
        uint256[] memory tokenIds = iNftValues.getNftIdList();
        for (uint i = 0; i < addresses.length; i++) {
            updateNftPrice(addresses[i], tokenIds[i]);
        }
    }

    // updates NftValues collection if its Floor Price changed
    function updateNftPrice(address collectionAddr, uint256 tokenId) public {
        if (nftPrices[collectionAddr][tokenId] == 0) {
            return iNftValues.updateNft(collectionAddr, tokenId, 0);
        } else if (iNftValues.getNftPrice(collectionAddr, tokenId) == nftPrices[collectionAddr][tokenId]) {
            return; // nothing to update
        } else {
            iNftValues.updateNft(collectionAddr, tokenId, nftPrices[collectionAddr][tokenId]);
            emit SentUpdateToNftValues(collectionAddr, tokenId, nftPrices[collectionAddr][tokenId]);
        }
    }

    // listens to NftValues if it requests Floor Price for a collection it needs info for
    function requestNftPrice(address collectionAddr, uint256 tokenId) external onlyNftValues {
        emit RequestFromNftValues(collectionAddr, tokenId);
        iNftValues.updateNft(collectionAddr, tokenId, nftPrices[collectionAddr][tokenId]);
        emit SentUpdateToNftValues(collectionAddr, tokenId, nftPrices[collectionAddr][tokenId]);
    }
}