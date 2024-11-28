// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftValues.sol";
import "./NftTrader.sol";

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
    NftTrader public nftTrader;
    NftValues public nftValues;

    mapping(uint256 => bool) public isBeingLiquidated; // Tracks NFTs currently in liquidation

    constructor() {
        pool = msg.sender; // LendingPool is the owner
        nftTrader = new NftTrader; //TODO get Trader with fixed address since 1:N
        nftValues = new NftValues;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value);

    // TODO Check if NFT is valid and owned by the sender
    function isNftValid(address sender, address collection, uint256 tokenId) public view returns (bool) {
        IERC721 nft = IERC721(collection);
        if (nft.ownerOf(tokenId) != sender) return false;
        return nftValues.checkContract(collection);
    }

    // Calculate the health factor for a user
    function getHealthFactor(address borrower) public returns (uint256) {
        uint256 totalCollateral = getCollateralValue(borrower);
        uint256 totalDebt = LendingPool(pool).totalBorrowedUsers(borrower);
        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(totalCollateral <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (totalCollateral * 100) / totalDebt;
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
                nftList[i].isLiquidatable = true;
            }
            liquidatableCollateral[borrower] = nftList;
        }
        else {
            for (uint256 i = 0; i < nftList.length; i++) {
                nftList[i].isLiquidatable = false;
            }
            Nft[] emptyList;
            liquidatableCollateral[borrower] = emptyList;
        }
    }

    //TODO change pool
    // function called by NftTrader when NFT gets bought by liquidator
    // delete given NFT from borrowers CollateralProfile
    // transfers NFT from CM to liquidator
    // this function calls liquidate in LendPool
    function liquidateNft(address liquidator, address collectionAddress, uint256 tokenId) public payable {
        uint256 amount = msg.value;
        require(liquidator != address(0), "Invalid liquidator address");
        require(amount >= getNftListingPrice(collectionAddress,tokenId), "Insufficient Ether sent");

        IERC721 nftContract = IERC721(collectionAddress);
        address borrower = nftContract.ownerOf(tokenId);

        // 1. update borrowersCollateral
        _deleteNftFromCollateralProfile(borrower, collectionAddress,tokenId);
        // 2. update liquidatableCollateral
        updateLiquidatableCollateral(borrower);

        // TODO change to directly pay pool?
        (bool success, ) = pool.call{value: amount}("");
        require(success, "Payment to pool failed");

        // transfer NFT to liquidator
        nftContract.safeTransferFrom(address(this), liquidator, tokenId);

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
    // TODO update pool
    function addCollateral(address collectionAddress, uint256 tokenId) public {
        require(isNftValid(msg.sender, collectionAddress, tokenId), "[*ERROR*] NFT collateral is invalid!");

        uint256 nftValue = getNftValue(collectionAddress, tokenId);
        CollateralProfile storage collateralProfile = borrowersCollateral[msg.sender];

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

        emit CollateralAdded(msg.sender, collectionAddress, tokenId);
    }

    // TODO: redeem your NFT
    function redeemCollateral(address collection, uint256 tokenId) public payable {
        // only if hf allows for it
        // if loan amount is 0, we automatically transfer NFT back
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getNftList(address borrower) private returns (Nft[]) {
        CollateralProfile memory collateralProfile = borrowersCollateral[borrower];
        return collateralProfile.nftList;
    }

    //TODO get the actual value from oracle nftvalue
    function getNftValue(address collectionAddress, uint256 tokenId) private returns (uint256) {
        return nftValues.getTokenIdPrice(collectionAddress, tokenId);
    }

    //TODO get the actual listing price for nft from nfttrader
    function getNftListingPrice(address collectionAddress, uint256 tokenId) private returns (uint256) {
        return;
    }

    function getNftListValue(address borrower) private returns (uint256) {
        Nft[] memory nftList = getNftList(borrower);
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

}
