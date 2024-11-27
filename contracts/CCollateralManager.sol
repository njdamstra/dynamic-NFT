// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftValues.sol";
import "./NftTrader.sol";

contract CollateralManager {

    mapping(address => CollateralProfile) public borrowersCollateral; // Tracks users collateral profile for multiple nfts

    struct CollateralProfile {
        uint256 nftListLength; //renamed from numNfts
        Nft[] nftList;
        uint256 totalCollateral;
    }

    struct Nft { //renamed from NftProvided
        address contractAddress;
        uint256 tokenId;
        uint256 value;
        IERC721 nftContract;
    }

    address public pool;
    NftTrader public nftTrader;
    NftValues public nftValues;

    mapping(uint256 => bool) public isBeingLiquidated; // Tracks NFTs currently in liquidation


    constructor() {
        pool = msg.sender; // LendingPool is the owner
        nftTrader = new NftTrader;
        nftValues = new NftValues;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Events for transparency

    event NFTListed(address indexed borrower, address indexed contractAddress, uint256 tokenId, uint256 valueListing);
    event CollateralAdded(address indexed borrower, address indexed contractAddress, uint256 tokenId, uint256 value);

    // Check if NFT is valid and owned by the sender
    function isNftValid(address sender, address contractAddress, uint256 tokenId) public view returns (bool) {
        IERC721 nft = IERC721(contractAddress);
        if (nft.ownerOf(tokenId) != sender) return false;
        return nftValues.checkContract(contractAddress);
    }

    // Retrieve the value of an NFT
    function getNFTValue(address contractAddress, uint256 tokenId) public view returns (uint256) {
        return nftValues.getNftIdPrice(contractAddress, tokenId);
    }

    // TODO: update func arguments and logic with pool
    // Calculate the health factor for a user
    function getHealthFactor(address borrower) public view returns (uint256) {
        uint256 totalCollateral = getCollateralProfilesValue(borrower);
        uint256 totalDebt = LendingPool(pool).totalBorrowedUsers(borrower);

        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(totalCollateral <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");

        return (totalCollateral * 100) / totalDebt;
    }

    // Dummy NFT liquidation function
    // TODO: 1) Determine price that we should list the NFT for.
    // 2) add a data structure tracking when the NFT has been officially liquidated. only then we should update the lend pool
    // Liquidate an NFT
    // END TODO
    function liquidateNFT(address borrower, address contractAddress, uint256 tokenId) external onlyPool returns (uint256) {
        require(!isBeingLiquidated[tokenId], "[*ERROR*] NFT is already being liquidated!"); // instead check the marketplace? -F
        isBeingLiquidated[tokenId] = true;

        CollateralProfile storage profile = borrowersCollateral[borrower];

        uint256 nftValue;
        uint256 indexToRemove;

        for (uint256 i = 0; i < profile.nftList.length; i++) {
            if (
                profile.nftList[i].contractAddress == contractAddress &&
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

        nftTrader.addListing(nftValue, contractAddress, tokenId);
        // TODO
        // await listing success before adding back to the pool
        // END TODO

        emit NFTListed(borrower, contractAddress, tokenId, nftValue);
        return nftValue;
    }

    // Aggregate collateral by adding NFTs to a borrower's profile
    function aggregateCollateral(address contractAddress, uint256 tokenId) external {
        require(isNftValid(msg.sender, contractAddress, tokenId), "[*ERROR*] NFT collateral is invalid!");
        uint256 nftValue = getNFTValue(contractAddress, tokenId);

        CollateralProfile storage profile = borrowersCollateral[msg.sender];

        for (uint256 i = 0; i < profile.nftList.length; i++) {
            require(
                !(profile.nftList[i].contractAddress == contractAddress && profile.nftList[i].tokenId == tokenId),
                "[*ERROR*] Duplicate NFT in collateral!"
            );
        }

        IERC721 nftContract = IERC721(contractAddress);
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        profile.nftList.push(Nft(contractAddress, tokenId, nftValue, nftContract));
        profile.nftListLength++;
        profile.totalCollateral += nftValue;

        emit CollateralAdded(msg.sender, contractAddress, tokenId, nftValue);
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getCollateralProfilesValue(address borrower) public view returns (uint256) {
        CollateralProfile storage profile = borrowersCollateral[borrower];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < profile.nftList.length; i++) {
            totalValue += profile.nftList[i].value;
        }
        return totalValue;
    }

    // TODO: take borrows collateral and transfer all of the collateral
    // Transfer collateral to the pool
    function transferCollateral(address borrower, uint256 totalLoan, uint256 netBorrowed) external onlyPool returns (bool) {
        uint256 totalCollateral = getCollateralProfilesValue(borrower);
        uint256 healthFactor = getHealthFactor(borrower);
        require(healthFactor >= 120, "[*ERROR*] Health factor would fall below 1.2!");

        return true;
    }

}
