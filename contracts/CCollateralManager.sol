// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {INftTrader} from "./interfaces/INftTrader.sol";
import {INftValues} from "./interfaces/INftValues.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract CollateralManager is IERC721Receiver {
    struct CollateralProfile {
        uint256 nftListLength;
        Nft[] nftList;
    }

    struct Nft {
        address collectionAddress;
        uint256 tokenId;
        IERC721 nftContract;
        bool isLiquidatable; // if NFT is currently being auctioned off or still hasn't been bought by liquidator
    }

    mapping(address => CollateralProfile) public borrowersCollateral;// Tracks users collateral profile for multiple nfts
    mapping(address => Nft[]) public liquidatableCollateral;
    mapping(uint256 => bool) public isBeingLiquidated; // Tracks NFTs currently in liquidation

    address public owner;
    address public poolAddr;
    address public nftTraderAddress;
    address public nftValuesAddress;
    address public portal;
    INftValues public iNftValues;
    INftTrader public iNftTrader;
    ILendingPool public iLendingPool;

    constructor() {
        // unsure if pool will be deploying this contract or if we'll deploy it through the deploy script
        owner = msg.sender; // LendingPool is the owner
    }

    // Initialize function to set dependencies
    function initialize(address _pool, address _nftTrader, address _nftValues, address _portal) external onlyOwner {
        require(poolAddr == address(0), "Already initialized");
        require(_pool != address(0) && _nftTrader != address(0) && _nftValues != address(0), "Invalid addresses");
        portal = _portal;
        poolAddr = _pool;
        nftTraderAddress = _nftTrader;
        nftValuesAddress = _nftValues;
        iNftTrader = INftTrader(nftTraderAddress);
        iNftValues = INftValues(nftValuesAddress);
        iLendingPool = ILendingPool(poolAddr);
    }

    modifier onlyPool() {
        require(msg.sender == poolAddr, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    modifier onlyPortal() {
        require(msg.sender == portal, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }
    // Events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing, uint256 timestamp);
    event NFTDeListed(address indexed collection, uint256 tokenId, uint256 timestamp);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value, uint256 timestamp);
    event Liquidated(address indexed borrower, address indexed collectionAddress, uint256 tokenId, uint256 liquidated, uint256 timestamp);
    event CollateralRedeemed(address indexed borrower, address indexed collectionAddress, uint256 tokenId);

    function isNftValid(address sender, address collection, uint256 tokenId) public view returns (bool) {
        IERC721 nft = IERC721(collection);
        if (nft.ownerOf(tokenId) != sender) return false;
        return true;
    }

    // Calculate the health factor for a user
    function getHealthFactor(address borrower) public returns (uint256) {
        uint256 totalCollateral = getCollateralValue(borrower);
        return calculateHealthFactor(borrower, totalCollateral);
    }

    function calculateHealthFactor(address borrower, uint256 collateralValue) public returns (uint256) {
        uint256 totalDebt = iLendingPool.getTotalBorrowedUsers(borrower);
        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(collateralValue <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (collateralValue * 100) / totalDebt;
    }


    // Get a list of all liquidatable NFTs for a user
    function getliquidatableCollateral(address borrower) public returns (Nft[] memory) {
        updateLiquidatableCollateral(borrower);
        return liquidatableCollateral[borrower];
    }

    // Update the liquidatableCollateral Mapping
    function updateLiquidatableCollateral(address borrower) private {
        uint256 healthFactor = getHealthFactor(borrower);
        Nft[] memory nftList = getNftList(borrower);

        // Clear the current storage array for the borrower
        delete liquidatableCollateral[borrower];

        if (healthFactor < 120) {
            for (uint256 i = 0; i < nftList.length; i++) {
                Nft memory item = nftList[i];
                if (!item.isLiquidatable) {
                    addTradeListing(borrower, item.collectionAddress, item.tokenId);
                    item.isLiquidatable = true;
                }
                // Manually push each updated item to the storage array
                liquidatableCollateral[borrower].push(item);
            }
        } else {
            for (uint256 i = 0; i < nftList.length; i++) {
                Nft memory item = nftList[i];
                if (item.isLiquidatable) {
                    delistTrade(item.collectionAddress, item.tokenId);
                }
            }
            // Ensure the storage array is cleared (already done above)
        }
    }


    function updateAllLiquidatableCollateral() external {
        address[] memory borrowerList = iLendingPool.getBorrowerList();
        for (uint256 i = 0; i < borrowerList.length; i++) {
            address borrower = borrowerList[i];
            updateLiquidatableCollateral(borrower);
        }
    }

    // This function is called only by the Pool after the Trader sold the NFT and called liquidate in the pool
    function liquidateNft(address borrower, address collectionAddress, uint256 tokenId, uint256 amount) public onlyPool {
        // 1. update borrowersCollateral
        _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);
        // 2. update liquidatableCollateral
        updateLiquidatableCollateral(borrower);
        // 3. emit event to show this NFT was liquidated!
        //TODO get actual timestamp
        emit Liquidated(borrower, collectionAddress, tokenId, amount, 1);
    }

    // @Helper for liquidateNft
    function _deleteNftFromCollateralProfile(
        address borrower,
        address collectionAddress,
        uint256 tokenId
    ) internal {
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftListLength;

        for (uint256 i = 0; i < length; i++) {
            Nft storage nft = collateralProfile.nftList[i];
            if (nft.collectionAddress == collectionAddress && nft.tokenId == tokenId) {
                // Swap the last element with the current element
                collateralProfile.nftList[i] = collateralProfile.nftList[length - 1];
                collateralProfile.nftList.pop(); // Remove the last element
                collateralProfile.nftListLength--; // Decrement the count

                break;
            }
        }
    }
    //TODO
    function addCollateral(address borrower, address collectionAddress, uint256 tokenId) public onlyPortal {
        // require(isNftValid(msg.sender, collectionAddress, tokenId), "[*ERROR*] NFT collateral is invalid!");
        // check whether borrower already exists
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        if (iLendingPool.isBorrower(borrower)) {
            for (uint256 i = 0; i < collateralProfile.nftList.length; i++) {
                require(!(collateralProfile.nftList[i].collectionAddress == collectionAddress && collateralProfile.nftList[i].tokenId == tokenId), "[*ERROR*] Duplicate NFT in collateral!");
            }
            // uint256 nftValue = getNftValue(collectionAddress, tokenId);

        } else {
            // if borrower does not exist yet, add him to the pool borrower mapping
            iLendingPool.addBorrowerIfNotExists(borrower);
            // CollateralProfile collateralProfile = CollateralProfile;
            collateralProfile.nftListLength = 0;
        }

        IERC721 nftContract = IERC721(collectionAddress);
        Nft memory nft = Nft(collectionAddress, tokenId, nftContract,false);
        collateralProfile.nftList.push(nft);
        collateralProfile.nftListLength++;

        registerNft(collectionAddress); // sends to NftValues to add to list of NFTs it keeps track of
        nftContract.approve(nftTraderAddress, tokenId); // Approves NftTrader to transfer NFT on CM's behalf -N
        //TODO emit value
        emit CollateralAdded(borrower, collectionAddress, tokenId,1,block.timestamp);
    }

    function redeemCollateral(address borrower, address collectionAddress, uint256 tokenId) public onlyPortal {
        uint256 healthFactor = getHealthFactor(borrower);
        // require(isNftValid(borrower, collectionAddress,tokenId), "[*ERROR* Nft not valid]");
        require(healthFactor > 150,"[*ERROR*] Health Factor has to be above 1.5 to redeem collateral!");

        // get a new List without the redeemed Nft
        Nft[] memory nftListCopy = getNftList(borrower);
        uint256 length = nftListCopy.length;

        bool found = false;
        for (uint256 i = 0; i < length; i++) {
            if (nftListCopy[i].collectionAddress == collectionAddress && nftListCopy[i].tokenId == tokenId) {
                // Swap with the last element and shorten the array
                nftListCopy[i] = nftListCopy[length - 1];
                found = true;
                length--;
                break;
            }
        }
        require(found, "NFT not found in collateral profile.");
        // Calculate the new health factor after removing the NFT
        Nft[] memory updatedNftList = new Nft[](length);
        for (uint256 i = 0; i < length; i++) {
            updatedNftList[i] = nftListCopy[i];
        }

        // check healthfactor for the new list
        uint256 newCollateralValue = getListValue(updatedNftList);
        uint256 newHealthFactor = calculateHealthFactor(borrower,newCollateralValue);

        require(newHealthFactor > 120, "[*ERROR*] Health Factor would fall below 1.2 after redemption!");

        // Proceed to redeem the NFT
        IERC721 nftContract = IERC721(collectionAddress);
        nftContract.transferFrom(address(this), borrower, tokenId);
        _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);

        emit CollateralRedeemed(borrower, collectionAddress, tokenId);
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getNftList(address borrower) public view returns (Nft[] memory) {
        // CollateralProfile memory collateralProfile = borrowersCollateral[borrower];
        // return collateralProfile.nftList;
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftList.length;
        Nft[] memory nftList = new Nft[](length);
        for (uint256 i = 0; i < length; i++) {
            nftList[i] = collateralProfile.nftList[i];
        }
        return nftList;
    }

    //TODO NATE get the actual value from oracle nftvalue
    function getNftValue(address collectionAddress) public view returns (uint256) {
        return iNftValues.getFloorPrice(collectionAddress);
    }


    //TODO NATE get the actual listing price for nft from nfttrader
    // function getNftListingPrice(address collectionAddress, uint256 tokenId) pure private returns (uint256) {
    //     return 0;
    // }

    function getNftListValue(address borrower) public view returns (uint256) {
        Nft[] memory nftList = getNftList(borrower);
        return getListValue(nftList);
    }

    function getListValue(Nft[] memory nftList) public view returns (uint256) {
        uint256 result = 0;
        for (uint i = 0; i < nftList.length; i++) {
            address collectionAddress = nftList[i].collectionAddress;
            result += getNftValue(collectionAddress); // Accumulate the value of each NFT
        }
        return result;
    }

    function getCollateralValue(address borrower) public view returns (uint256) {
        return getNftListValue(borrower);
    }

    function addTradeListing(address borrower, address collection, uint256 tokenId) private {
        uint256 basePrice = getBasePrice(collection);
        // determine basePrice calculation.
        uint256 duration = 20000; // 20000 seconds
        iNftTrader.addListing(basePrice, collection, tokenId, true, duration, borrower);

        //TODO emit NFTListed event
        emit NFTListed(borrower, collection, tokenId, basePrice, block.timestamp);
    }

    function delistTrade(address collection, uint256 tokenId) private {
        iNftTrader.delist(collection, tokenId);
        // emit NFTDeListed event
        emit NFTDeListed(collection, tokenId, block.timestamp);

    }

    function getBasePrice(address collection) public view returns (uint256) {
        uint256 floorprice = getNftValue(collection);
        return (floorprice * 95) / 100;
    }
    function registerNft(address collection) private {
        iNftValues.addCollection(collection);
    }
    // for testing
    function getCollateralProfile(address borrower) external view returns (CollateralProfile memory) {
        return borrowersCollateral[borrower];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
