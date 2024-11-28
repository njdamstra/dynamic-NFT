// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftValues.sol";
import "./NftTrader.sol";

contract CollateralManager {

    mapping(address => CollateralProfile) public borrowersCollateral; // Tracks users collateral profile for multiple nfts
    // list of liquidatable nfts

    struct CollateralProfile {
        uint256 nftListLength; //renamed from numNfts
        Nft[] nftList;
        // uint256 totalCollateral; // this isn't up to date
    }

    struct Nft { //renamed from NftProvided
        address collectionAddress;
        uint256 tokenId;
        // uint256 value; // not up to date
        IERC721 nftContract;
        bool liquidatable; // if NFT is currently being auctioned off or still hasn't been bought by liquidator
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

    // TODO: update func arguments and logic with pool
    // Calculate the health factor for a user
    function getHealthFactor(address borrower) public view returns (uint256) {
        uint256 totalCollateral = getCollateralValue(borrower);
        uint256 totalDebt = LendingPool(pool).totalBorrowedUsers(borrower);

        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(totalCollateral <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");

        return (totalCollateral * 100) / totalDebt;
    }

    // TODO: 1) Determine price that we should list the NFT for.
    // 2) add a data structure tracking when the NFT has been officially liquidated. only then we should update the lend pool
    // Liquidate an NFT

    function liquidatableCollateral(address borrower) public view returns (Nft[] memory) {
        require(getHealthFactor(borrower) < 120, "[*ERROR*] Healthfactor too high!");
        return getNftList(borrower);
    }

    // TODO: function called by NftTrader when NFT gets bought by liquidator
    // delete given NFT from borrowers NftProfile
    // transfers NFT from CM to liquidator
    //
    // this function calls liquidate in LendPool
    function liquidateNFT(address liquidator, address collection, uint256 tokenId) external returns (uint256) {
        require(!isBeingLiquidated[tokenId], "[*ERROR*] NFT is already being liquidated!"); // instead check the marketplace? -F
        isBeingLiquidated[tokenId] = true;

        CollateralProfile storage profile = borrowersCollateral[borrower];

        uint256 nftValue;
        uint256 indexToRemove;

        for (uint256 i = 0; i < profile.nftList.length; i++) {
            if (
                profile.nftList[i].collectionAddress == collection &&
                profile.nftList[i].tokenId == tokenId
            ) {
                nftValue = profile.nftList[i].value;
                indexToRemove = i;
                break;
            }
        }

        require(nftValue > 0, "[*ERROR*] NFT not found in collateral!");

        profile.nftList[indexToRemove] = profile.nftList[profile.nftList.length - 1];
        profile.nftList.pop();
        profile.nftListLength--;
        profile.totalCollateral -= nftValue;

        nftTrader.addListing(nftValue, collection, tokenId);
        // TODO
        // await listing success before adding back to the pool
        // END TODO

        emit NFTListed(borrower, collection, tokenId, nftValue);
        return nftValue;
    }

    // Aggregate collateral by adding NFTs to a borrower's profile
    // automatically transfers collateral to CM even before initializing there loan
    // if added collateral boosts its health factor enough, deList collateral from NftTrader and mark NftProvided auctionable to false.
    function addCollateral(address collection, uint256 tokenId) external {
        require(isNftValid(msg.sender, collection, tokenId), "[*ERROR*] NFT collateral is invalid!");
        uint256 nftValue = getNftValue(collection, tokenId);

        CollateralProfile storage profile = borrowersCollateral[msg.sender];

        for (uint256 i = 0; i < profile.nftList.length; i++) {
            require(
                !(profile.nftList[i].collectionAddress == collection && profile.nftList[i].tokenId == tokenId),
                "[*ERROR*] Duplicate NFT in collateral!"
            );
        }
        IERC721 nftContract = IERC721(collection);
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        profile.nftList.push(Nft(collection, tokenId, nftValue, nftContract));
        profile.nftListLength++;
        profile.totalCollateral += nftValue;

        emit CollateralAdded(msg.sender, collection, tokenId, nftValue);
    }

    // TODO: redeem your NFT
    function redeemCollateral(address collection, uint256 tokenId) public payable {
        // only if hf allows for it
        // if loan amount is 0, we automatically transfer NFT back
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getCollateralValue(address borrower) public view returns (uint256) {
        return getNftListValue(borrower);
    }

    function getNftList(address borrower) public view returns (Nft[]) {
        CollateralProfile memory collateralProfile = borrowersCollateral[borrower];
        return collateralProfile.nftList;
    }

    function getNftValue(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        return nftValues.getTokenIdPrice(collectionAddress, tokenId);
    }

    function getNftListValue(address borrower) public view returns (uint256) {
        Nft[] memory nftList = getNftList(borrower);
        uint256 result = 0;
        for (uint256 i = 0; i < nftList.length; i++) {
            address collectionAddress = nftList[i].collectionAddress;
            uint256 tokenId = nftList[i].tokenId;
            result += getNftValue(collectionAddress, tokenId); // Accumulate the value of each NFT
        }
        return result;
    }

}
