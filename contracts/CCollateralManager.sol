// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPool} from "./CLendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftValues.sol";
import "./NftTrader.sol";

contract CollateralManager {

    mapping(address => CollateralProfile) public borrowersCollateral; // Tracks users collateral profile for multiple nfts

    struct CollateralProfile {
        uint256 numNfts;
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
    NftTrader public trader;
    NftValues public nftValues;

    constructor() {
        pool = msg.sender; // LendingPool is the owner
        trader = new NftTrader;
        nftValues = new NftValues;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    // Events for transparency
    event NFTLiquidated(address indexed borrower, uint256 indexed nftId, uint256 valueRecovered);


    // TODO: check if the NFT contract is supported by Alchemy in NftValues.sol
    function isNftValid(address sender, address nftContract, uint256 tokenId) external returns (bool) {
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == sender, "Caller must own the NFT");
        // TODO: check if it's supported by Alchemy in NftValues.sol
        bool success = nftValues.checkContract(nftContract);
        if (!success) {
            return false;
        }
        return true;
    }


    // Retrieves the value of an NFT
    function getNFTValue(address contractAddr, uint256 tokenId) external view returns (uint256) {
        return nftValues.getNftIdPrice(contractAddr, tokenId);
    }

    // Calculates the health factor for a user
    // TODO: update func arguments and logic
    function getHealthFactor(address borrower, uint256 nftId) external view returns (uint256) {
        uint256 nftValue = nftValues[borrower][nftId];
        uint256 debt = LendingPool(pool).netBorrowedUsers(borrower);

        if (debt == 0) return type(uint256).max; // No debt means infinite health factor
        require(nftValue <= type(uint256).max / 100, "[*ERROR*] NFT value too high!");


        return (nftValue * 100) / debt;
    }

    // Dummy NFT liquidation function
    // TODOs: 1) Determine price that we should list the NFT for.
    // 2) add a data structure tracking when the NFT has been officially liquidated. only then we should update the lend pool
    function liquidateNFT(address borrower, address contractAddr, uint256 tokenId) external onlyPool returns (uint256) {        
        // Retrieve and delete the NFT value and ownership
        uint256 nftValue = nftValues[borrower][nftId];
        delete nftValues[borrower][nftId];
        delete nftOwners[nftId];

        trader.addListing(price, contractAddr, tokenId);

        emit NFTLiquidated(borrower, nftId, nftValue);
        return nftValue;
    }
    
    // allows user to use multiple NFTs in there initial NFT loan by aggregating them together using this function!
    function aggregateCollateral(address contractAddr, uint256 tokenId) external {
        // validate the collateral --> caller is the owner of the NFT, NFT is registered!
        // retrieve NFTs value we set for it
        // add it to this borrows CollateralProfile
        IERC721 nft = IERC72(nftContract);
        require(collateralManager.isNftValid(msg.sender, nft, contractAddr, tokenId), "[*ERROR*] NFT collateral is not valid");
        uint256 nftValue = getNFTValue(contractAddr, tokenId);
        Nft nftData;
        nftData.contractAddress = contractAddr;
        nftData.tokenId = tokenId;
        nftData.value = nftValue;
        nftData.nftContract = nft;

        if (borrowersCollateral[msg.sender] == address(0)) {
            CollateralProfile profile;
            profile.numNfts = 1;
            Nft[] nftList;
            nftList[0] = nftData;
            profile.nftList = nftList;
            profile.totalCollateral = nftValue;
            borrowersCollateral[msg.sender] = profile;
        } else {
            // TODO: check that they aren't reusing the same NFT.
            CollateralProfile profile = borrowersCollateral[msg.sender];
            Nft[] nftList = profile.nftList;
            profile.totalCollateral += nftValue;
            profile.nftList[profile.numNfts] = nftData;
            profile.numNfts += 1;
            borrowersCollateral[msg.sender] = profile;
        }
    }

    // TODO: combine all of the NFTs value in users profile with there updated values
    function getCollateralProfilesValue(address borrower) external returns (uint256) {
        return 100000;
    }

    // TODO: take borrows collateral and transfer all of the collateral
    function transferCollateral(address borrower, uint256 totalLoan, uint256 netBorrowed) external returns (bool) {
        uint256 totalCol = getCollateralProfilesValue(borrower);
        uint256 healthFactor = (nftValue * 100) / (netBorrowed + totalLoan); // Health factor
        require(healthFactor >= 120, "[*ERROR*] Health factor would fall below 1.2!");


        return true;
    }

    // TODO: helper function for transferCollateral of transfering one NFT
    function transferNft(address borrower, IERC721 nftContract, uint256 tokenId) external returns (bool) {
        // security checks
        bool success = isNftValid(borrower, nftContract, tokenId);
        require(nft.isApprovedForAll(sender, pool) || nft.getApproved(tokenId) == address(this), "Contract must be approved to transfer the NFT"
        );
        // TODO: Transfer Nft

        // END TODO
        return true;
    }

    // TODO: recollateralize loan with more collateral
    function addCollateral(address contractAddr, uint256 tokenId) {
    }



    
}
