// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftValues.sol";
import "./NftTrader.sol";
import {INftTrader} from "../interfaces/INftTrader.sol";
import {INftValues} from "../interfaces/INftValues.sol";

contract CollateralManager {

    mapping(address => CollateralProfile) public borrowersCollateral;// Tracks users collateral profile for multiple nfts
    mapping(address => Nft[]) public liquidatableCollateral;

    struct CollateralProfile {
        uint256 nftListLength; //renamed from numNfts
        Nft[] nftList;
    }

    struct Nft { //renamed from NftProvided
        address collectionAddress;
        uint256 tokenId;
        IERC721 nftContract;
        bool isLiquidatable; // if NFT is currently being auctioned off or still hasn't been bought by liquidator
    }

    address public pool;
    address public nftTraderAddress;
    address public nftValuesAddress;
    INftValues public iNftValues;
    INftTrader public iNftTrader;

    mapping(uint256 => bool) public isBeingLiquidated; // Tracks NFTs currently in liquidation

    constructor() {
        // unsure if pool will be deploying this contract or if we'll deploy it through the deploy script
        pool = msg.sender; // LendingPool is the owner
    }

    // Initialize function to set dependencies
    function initialize(address _pool, address _nftTrader, address _nftValues) external {
        require(pool == address(0), "Already initialized");
        require(_pool != address(0) && _nftTrader != address(0) && _nftValues != address(0), "Invalid addresses");

        pool = _pool;
        nftTraderAddress = _nftTrader;
        nftValuesAddress = _nftValues;
        iNftTrader = INftTrader(nftTraderAddress);
        iNftValues = INftValues(nftValuesAddress);
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing, uint256 timestamp);
    event NFTDeListed(address indexed collection, uint256 tokenId, uint256 timestamp);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value, uint256 timestamp);
    event Liquidated(address indexed borrower, address indexed collectionAddress, uint256 tokenId, uint256 liquidated, uint256 timestamp);

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

    function calculateHealthFactor(address borrower, uint256 collateralValue) private returns (uint256) {
        uint256 totalDebt = LendingPool(pool).totalBorrowedUsers(borrower);
        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(collateralValue <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (collateralValue * 100) / totalDebt;
    }

    // Get a list of all liquidatable NFTs for a user
    function getliquidatableCollateral(address borrower) public returns (Nft[]) {
        updateLiquidatableCollateral(borrower);
        return liquidatableCollateral[borrower];
    }

    // Update the liquidatableCollateral Mapping
    function updateLiquidatableCollateral(address borrower) private {
        uint256 healthFactor = getHealthFactor(borrower);
        Nft[] nftList = getNftList(borrower);
        if (healthFactor < 120) {
            for (uint256 i = 0; i < nftList.length; i++) {
                Nft item = nftList[i];
                if (!item.isLiquidatable) {
                    addTradeListing(borrower, item.collectionAddress, item.tokenId);
                    nftList[i].isLiquidatable = true;
                }
            }
            liquidatableCollateral[borrower] = nftList;
        }
        else {
            for (uint256 i = 0; i < nftList.length; i++) {
                Nft item = nftList[i];
                if (item.isLiquidatable) {
                    nftList[i].isLiquidatable = false;
                    delistTrade(item.collectionAddress, item.tokenId);
                }
            }
            Nft[] emptyList;
            liquidatableCollateral[borrower] = emptyList;
        }
    }

    // This function is called only by the Pool after the Trader sold the NFT and called liquidate in the pool
    function liquidateNft(address borrower, address collectionAddress, uint256 tokenId, uint256 amount) public onlyPool {
        // 1. update borrowersCollateral
        _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);
        // 2. update liquidatableCollateral
        updateLiquidatableCollateral(borrower);
        // 3. emit event to show this NFT was liquidated!
        emit Liquidated(borrower, collectionAddress, tokenId, amount);
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

    // Aggregate collateral by adding NFTs to a borrower's profile
    // automatically transfers collateral to CM even before initializing there loan
    // if added collateral boosts its health factor enough, deList collateral from NftTrader and mark NftProvided auctionable to false.

    function addCollateral(address collectionAddress, uint256 tokenId) public {
        require(isNftValid(msg.sender, collectionAddress, tokenId), "[*ERROR*] NFT collateral is invalid!");

        // uint256 nftValue = getNftValue(collectionAddress, tokenId);
        CollateralProfile memory collateralProfile = borrowersCollateral[msg.sender];

        for (uint256 i = 0; i < collateralProfile.nftList.length; i++) {
            require(
                !(collateralProfile.nftList[i].collectionAddress == collectionAddress && collateralProfile.nftList[i].tokenId == tokenId),
                "[*ERROR*] Duplicate NFT in collateral!"
            );
        }
        IERC721 nftContract = IERC721(collectionAddress);
        nftContract.transferFrom(msg.sender, address(this), tokenId);
        collateralProfile.nftList.push(Nft(collectionAddress, tokenId, nftContract,false));
        collateralProfile.nftListLength++;
        nftContract.approve(nftTraderAddress, tokenId); // Approves NftTrader to transfer NFT on CM's behalf -N

        emit CollateralAdded(msg.sender, collectionAddress, tokenId);
    }

    function redeemCollateral(address borrower, address collectionAddress, uint256 tokenId) public {
        uint256 healthFactor = getHealthFactor(borrower);
        require(isNftValid(borrower, collectionAddress,tokenId), "[*ERROR* Nft not valid]");
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

        // check healthfactor for the new list
        uint256 newCollateralValue = getListValue(borrower, nftListCopy);
        uint newHealthFactor = calculateHealthFactor(borrower,newCollateralValue);

        if (found && healthFactor > 120) {
            // update collateral profile
            Nft[] nftContract = IERC721(collectionAddress);
            nftContract.transferFrom(address(this),borrower,tokenId);
            _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);
        }
        require(healthFactor > 120,"[*ERROR*] Health Factor has to be above 1.2!");
        require(found, "[*ERROR*] Nft was not found!");
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getNftList(address borrower) private returns (Nft[]) {
        CollateralProfile memory collateralProfile = borrowersCollateral[borrower];
        return collateralProfile.nftList;
    }

    //TODO get the actual value from oracle nftvalue
    function getNftValue(address collectionAddress, uint256 tokenId) private returns (uint256) {
        return iNftValues.getTokenIdPrice(collectionAddress, tokenId);
    }

    //TODO get the actual value from oracle nftvalue
    function getNftValue(Nft nft) private returns (uint256) {
        return iNftValues.getTokenIdPrice(nft.collectionAddress, nft.tokenId);
    }

    //TODO get the actual listing price for nft from nfttrader
    function getNftListingPrice(address collectionAddress, uint256 tokenId) private returns (uint256) {
        return;
    }

    function getNftListValue(address borrower) private returns (uint256) {
        Nft[] memory nftList = getNftList(borrower);
        return getListValue(borrower, nftList);
    }

    function getListValue(address borrower, Nft[] memory nftList) private returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < nftList.length; i++) {
            address collectionAddress = nftList[i].collectionAddress;
            uint256 tokenId = nftList[i].tokenId;
            result += getNftValue(collectionAddress, tokenId); // Accumulate the value of each NFT
        }
        return result;
    }


    function getCollateralValue(address borrower) public returns (uint256) {
        return getNftListValue(borrower);
    }

    // TODO: create a basePrice for the given NFT, probably take it's floor price and subtract it's proportion of the debt + interest
    function addTradeListing(address borrower, address collection, uint256 tokenId) external private {
        uint256 basePrice = getBasePrice(collection, tokenId);
        // determine basePrice calculation.
        uint256 duration = 1000;
        iNftTrader.addListing(basePrice, collection, tokenId, true, duration, borrower);

        // emit NFTListed event
        emit NFTListed(borrower, collection, tokenId, basePrice, block.timestamp());
    }

    //TODO error?
    function delistTrade(address collection, uint256 tokenId) external private {
        iNftTrader.delist(collection, tokenId);
        // emit NFTDeListed event
        emit NFTDeListed(collection, tokenId, block.timestamp());
    }

    // TODO assume hf is one, get proportion of nft to debt + interest
    function getBasePrice(address collection, uint256 tokenId) public returns (uint256) {
        return;
    }

}
