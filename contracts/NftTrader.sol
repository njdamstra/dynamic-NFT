// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ILendingPool} from "../contracts/interfaces/ILendingPool.sol";

contract NftTrader {
    mapping(address => mapping(uint256 => Listing)) public listings; // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated

    struct Listing {
        address seller; // in the case of one lending pool, this will always be the same (CM)
        address collection;
        uint256 tokenId;
        uint256 basePrice; // first bid has to be at least this amount
        uint256 auctionStarted; // when listing was created
        uint256 auctionEnds; // how long auction will last
        uint256 highestBid; // highest bid if one 
        address highestBidder; // addr of the last bid
        bool buyNow; // if auction duration has passed, then the liquidator can buy immediately at basePrice
        address originalOwner;
    }

    address public collateralManagerAddr;
    address public poolAddr;
    uint public numCollections;
    ILendingPool public iLendingPool;
    address public owner;
    address public portal;

    constructor() {
        owner = msg.sender;
    }

    // Initialize function to set dependencies
    function initialize(address _collateralManagerAddr, address _pool, address _portal) external onlyOwner {
        require(collateralManagerAddr == address(0), "Already initialized");
        require(_collateralManagerAddr != address(0) && _pool != address(0), "Invalid addresses");

        collateralManagerAddr = _collateralManagerAddr;
        poolAddr = _pool;
        iLendingPool = ILendingPool(poolAddr);
        portal = _portal;
    }

    modifier onlyCollateralManager() {
        require(msg.sender == collateralManagerAddr, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    modifier onlyPortal() {
        require(msg.sender == portal, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    // Events for transparency
    event NFTListed(address indexed collection, uint256 indexed tokenId, uint256 basePrice, address seller, bool auction, uint256 timestamp);
    event NFTDelisted(address indexed collection, uint256 indexed tokenId, uint256 timestamp);
    event NFTPurchased(address indexed collection, uint256 indexed tokenId, uint256 price, address buyer, uint256 timestamp);
    event Withdrawal(address indexed destination, uint256 amount);

    // Add an NFT listing
    function addListing(uint256 basePrice, address collection, uint256 tokenId, bool auction, uint256 duration, address originalOwner) public onlyCollateralManager {
        IERC721 nftContract = IERC721(collection);


        require(nftContract.ownerOf(tokenId) == collateralManagerAddr, "[*ERROR*] collateral manager must own the NFT!");
        //TODO NATE is this correct/necessary?
        //require(nftContract.isApproved(collateralManagerAddr, address(this), tokenId), "[*ERROR*] Contract is not approved by collateral manager!"); // might delete this so that approval only happens when purchased

        // check for no redundant listings currently;
        if (isListed(collection, tokenId)) {
            //TODO maybe have an update function that'll only update it's basePrice
            return;
        }

        // Add the listing
        uint256 timestamp = block.timestamp;
        uint256 auctionEnds = timestamp + duration;
        listings[collection][tokenId] = Listing(collateralManagerAddr, collection, tokenId, basePrice, timestamp, auctionEnds, 0, address(0), !auction, originalOwner);

        // create a listing event
        emit NFTListed(collection, tokenId, basePrice, collateralManagerAddr, auction, timestamp);
    }

    // Delist an NFT 
    // (this shouldn't be called when some purchased the nft, this should only be called when the borrower wants to reedem their nft)
    function delist(address collection, uint256 tokenId) public onlyCollateralManager {
        // require(checkTokenId(collection, tokenId), "[*ERROR*] NFT is not listed!");
        // maybe returns bool if it was sold. we don't have a data structure keeping track of if a NFT was sold...
        if (isListed(collection, tokenId)) {
            // Remove the listing
            Listing storage item = listings[collection][tokenId];
            if (item.highestBidder != address(0)) {  // can't delist if someone already placed a bid on it!
                endAuction(collection, tokenId);
                return; // someone placed a bid on it --> true it's purchased and can't be delisted.
            } else {
                delete listings[collection][tokenId];
                emit NFTDelisted(collection, tokenId, block.timestamp);
                return; // successfully delisted and no one placed a bid on it!
            }
        }
        return; // not listed thus no one purchased it bc otherwise CM wouldn't call delist
        // TODO can't delist if auction has ended and has a highest bidder!!!
    }

    function placeBid(address bidder, address collection, uint256 tokenId) external payable onlyPortal {
        require(isListed(collection, tokenId), "token not listed");
        Listing storage item = listings[collection][tokenId];
        require(item.auctionEnds > block.timestamp, "Auction has ended");
        require(msg.value > item.highestBid && msg.value >= item.basePrice, "Bid not high enough");

        // Refund the previous highest bidder
        if (item.highestBidder != address(0)) {
            (bool refundSuccess, ) = item.highestBidder.call{value: item.highestBid}("");
            require(refundSuccess, "Refund to previous bidder failed");
        }

        // Update the highest bid
        item.highestBid = msg.value;
        item.highestBidder = bidder;
        // TODO: do we need to update listings map with new item or is it changed directly?
        // listings[collection][tokenId] = item; // to update the listing or does storage item mean we can mutate 'item' without creating a new struct
    }

    // called by either the purchase function or the highest bidder.
    function endAuction(address collection, uint256 tokenId) public {
        // called only if auction duration has been completed.
        // if there is a bid, automatically transfer NFT to highest bidders address
        // if no bid made, change buyNow bool from false to true
        require(isListed(collection, tokenId), "Token not listed for sale");
        Listing storage item = listings[collection][tokenId];
        require(item.auctionEnds <= block.timestamp, "Auction has not ended");
        // now we know auction can be ended
        address winner = item.highestBidder;
        if (winner == address(0)) {
            listings[collection][tokenId].buyNow = true;
            return; // no one placed a bid before it ended --> buyNow at basePrice
        }
        IERC721(collection).safeTransferFrom(item.seller, winner, tokenId);
        // Transfer the funds to the pool
        (bool success, ) = poolAddr.call{value: item.highestBid}("");
        require(success, "Transfer to pool failed");

        iLendingPool.liquidate(item.originalOwner, collection, tokenId, item.highestBid);

        delete listings[collection][tokenId];
    }

    // purchase an NFT (user purchases from CollateralManager) ??-F
    function purchase(address buyer, address collection, uint256 tokenId) external payable onlyPortal {
        require(isListed(collection, tokenId), "NFT not listed");
        Listing memory item = listings[collection][tokenId];
        // require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        endAuction(collection, tokenId);
        uint256 amount = msg.value;
        require(item.buyNow, "[*ERROR*] NFT is not available to be purchased, it is still being auctioned");
        require(msg.value >= item.basePrice, "[*ERROR*] Insufficient funds!");

        // Update balances and transfer NFT
        IERC721 token = IERC721(collection);
        token.safeTransferFrom(item.seller, buyer, tokenId);
        // send funds back to the pool

        (bool success, ) = poolAddr.call{value: msg.value}("");
        require(success, "Transfer to pool failed");

        iLendingPool.liquidate(item.originalOwner, collection, tokenId, amount);
        // Remove the listing
        delete listings[collection][tokenId];
        emit NFTPurchased(collection, tokenId, item.basePrice, buyer,block.timestamp);
    }

    // Withdraw funds NOT NEEDED
    // function withdraw(address payable destinationAddress) public onlyCollateralManager {
    //     require(0 < balances[destinationAddress], "[*ERROR*] nothing to be withdrawed");
    //     (bool success, ) = destinationAddress.call{value: amount}("");
    //     require(success, "[*ERROR*] Withdrawal failed!");
    //     emit Withdrawal(destinationAddress, balances[destinationAddress]);
    //     balances[destinationAddress] = 0;
    // }

    receive() external payable {}

    // for the liquidator to get the data ?? not necessary
    // @Helper
    function viewListing(address collection, uint256 tokenId) public view returns (Listing memory) {
        return listings[collection][tokenId];
    }

    // called within this function to see if this nft is currently listed
    // called by CM to check on its status
    function isListed(address collection, uint256 tokenId) public view returns (bool) {
        if (listings[collection][tokenId].basePrice == 0) {
            return false;
        }
        return true;
    }

    // function notPurchased(address collection, uint256 tokenId) external returns (bool) {
    //     Listing storage item = listings[collection][tokenId];
    //     uint256 timeNow = block.timestamp;
    //     if 
    // }

}