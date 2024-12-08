// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ILendingPool} from "../contracts/interfaces/ILendingPool.sol";
import {IAddresses} from "./interfaces/IAddresses.sol";

contract NftTrader is IERC721Receiver {
    // mapping(address => mapping(uint256 => Listing)) public listings; // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated

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
    // Array to store listings
    Listing[] public listings;

    // Mapping to track listing indices: collection address => tokenId => index in listings array
    mapping(address => mapping(uint256 => uint256)) private listingIndex;

    // Mapping to check if a listing exists: collection address => tokenId => bool
    mapping(address => mapping(uint256 => bool)) public isListingMapping;

    struct BoughtReceipt {
        address buyer;
        address collection;
        uint256 tokenId;
        uint256 price;
        address originalOwner;
        uint256 timestamp;
    }
    BoughtReceipt[] public boughtList;
    mapping(address => mapping(uint256 => uint256)) private boughtIndex;
    

    address public collateralManagerAddr;
    address public poolAddr;
    uint public numCollections;
    ILendingPool public iLendingPool;
    address public owner;
    address public portal;

    address public addressesAddr;
    IAddresses public addresses;

    constructor(address _addressesAddr) {
        owner = msg.sender;
        addressesAddr = _addressesAddr;
        addresses = IAddresses(addressesAddr);
    }

    // Initialize function to set dependencies
    function initialize() external onlyOwner {
        // require(collateralManagerAddr == address(0), "Already initialized");
        // require(_collateralManagerAddr != address(0) && _pool != address(0), "Invalid addresses");
        collateralManagerAddr = addresses.getAddress("CollateralManager");
        poolAddr = addresses.getAddress("LendingPool");
        portal = addresses.getAddress("UserPortal");
        iLendingPool = ILendingPool(poolAddr);
        boughtList.push(BoughtReceipt(address(0), address(0), 0, 0, address(0), 0));
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
    event NFTListed(address indexed collection, uint256 indexed tokenId, uint256 basePrice, address indexed seller, bool auction, uint256 timestamp);
    event NFTDelisted(address indexed collection, uint256 indexed tokenId, uint256 timestamp);
    event NFTPurchased(address indexed collection, uint256 indexed tokenId, uint256 price, address indexed buyer, uint256 timestamp);
    event AuctionEndedWithNoWinner(address indexed collection, uint256 indexed tokenId);
    event AuctionWon(address indexed winner, address indexed collection, uint256 tokenId, uint256 amount);
    event NewBid(address indexed bidder, address indexed collection, uint256 tokenId, uint256 amount);
    event DelistingFailed(address indexed collection, uint256 indexed tokenId, string reason);

    function isListing(address collection, uint256 tokenId) public view returns (bool) {
        return isListingMapping[collection][tokenId];
    }

    function getListing(address collection, uint256 tokenId) public view returns (Listing memory) {
        require(isListingMapping[collection][tokenId], "[*ERROR*] Listing does not exist!");

        uint256 index = listingIndex[collection][tokenId];
        return listings[index];
    }


    // Add an NFT listing
    function addListing(uint256 basePrice, address collection, uint256 tokenId, bool auction, uint256 duration, address originalOwner) public onlyCollateralManager {
        IERC721 nftContract = IERC721(collection);


        require(nftContract.ownerOf(tokenId) == collateralManagerAddr, "[*ERROR*] collateral manager must own the NFT!");
        //TODO NATE is this correct/necessary?
        //require(nftContract.isApproved(collateralManagerAddr, address(this), tokenId), "[*ERROR*] Contract is not approved by collateral manager!"); // might delete this so that approval only happens when purchased

        // check for no redundant listings currently;
        if (isListing(collection, tokenId)) {
            //TODO maybe have an update function that'll only update it's basePrice
            return;
        }

        // Add the listing
        uint256 timestamp = block.timestamp;
        uint256 auctionEnds = timestamp + duration;
        Listing memory newListing = Listing(collateralManagerAddr, collection, tokenId, basePrice, timestamp, auctionEnds, 0, address(0), !auction, originalOwner);

        listings.push(newListing);
        listingIndex[collection][tokenId] = listings.length - 1;
        isListingMapping[collection][tokenId] = true;

        // create a listing event
        emit NFTListed(collection, tokenId, basePrice, collateralManagerAddr, auction, timestamp);
    }

    function deleteListing(address collection, uint256 tokenId) private {
        if (!isListingMapping[collection][tokenId]) {
            return; // not in list
        }
        uint256 index = listingIndex[collection][tokenId];
        uint256 lastIndex = listings.length - 1;
        if (index != lastIndex) {
            // Swap the listing to delete with the last listing
            Listing memory lastListing = listings[lastIndex];
            listings[index] = lastListing;
            // Update the mapping for the moved listing
            listingIndex[lastListing.collection][lastListing.tokenId] = index;
        }
        // Remove the last listing
        listings.pop();
        // Remove the listing from the mappings
        delete listingIndex[collection][tokenId];
        delete isListingMapping[collection][tokenId];
    }

    // Delist an NFT 
    // (this shouldn't be called when some purchased the nft, this should only be called when the borrower wants to reedem their nft)
    function delist(address collection, uint256 tokenId) public onlyCollateralManager {
        // require(checkTokenId(collection, tokenId), "[*ERROR*] NFT is not listed!");
        // maybe returns bool if it was sold. we don't have a data structure keeping track of if a NFT was sold...
        endAllConcludedAuctions();
        uint state = listingState(collection, tokenId);
        if (state == 1) { // bought
            emit DelistingFailed(collection, tokenId, "Bought");
            return;
        } else if (state == 2) { // not listed or bought
            emit DelistingFailed(collection, tokenId, "Not Listed Or Bought");
            return;
        } else if (state == 3) { // has a bid
            refundBidder(collection, tokenId);
        }
        deleteListing(collection, tokenId);
        emit NFTDelisted(collection, tokenId, block.timestamp);
        return; // not listed thus no one purchased it bc otherwise CM wouldn't call delist
    }

    function listingState(address collection, uint256 tokenId) public view returns (uint) {
        uint256 indexB = boughtIndex[collection][tokenId];
        if (boughtList[indexB].collection == collection) {
            return 1; // bought
        }
        if (!isListing(collection, tokenId)) {
            return 2; // not listed or bought
        }
        if (getListing(collection, tokenId).highestBid != 0) {
            return 3; // has a bid placed on it
        }
        return 0; // is returnable
    }

    function refundBidder(address collection, uint256 tokenId) internal {
        endAllConcludedAuctions();
        uint state = listingState(collection, tokenId);
        if (state != 3) {
            return; // no bid, not listed, or bought
        }
        Listing storage item = listings[listingIndex[collection][tokenId]];
        (bool refundSuccess, ) = item.highestBidder.call{value: item.highestBid}("");
        require(refundSuccess, "Refund to highest bidder failed");
    }

    function placeBid(address bidder, address collection, uint256 tokenId) external payable onlyPortal {
        require(isListing(collection, tokenId), "token not listed");
        Listing storage item = listings[listingIndex[collection][tokenId]];
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

        emit NewBid(bidder, collection, tokenId, msg.value);
        // TODO: do we need to update listings map with new item or is it changed directly?
        // listings[collection][tokenId] = item; // to update the listing or does storage item mean we can mutate 'item' without creating a new struct
    }

    // called by either the purchase function or the highest bidder.
    function endAuction(address collection, uint256 tokenId) public {
        // called only if auction duration has been completed.
        // if there is a bid, automatically transfer NFT to highest bidders address
        // if no bid made, change buyNow bool from false to true
        if (!isListing(collection, tokenId)) {
            return;
        }
        Listing storage item = listings[listingIndex[collection][tokenId]];
        if (item.auctionEnds > block.timestamp) {
            return;
        }
        // now we know auction can be ended
        address winner = item.highestBidder;
        if (winner == address(0)) {
            item.buyNow = true;
            emit AuctionEndedWithNoWinner(collection, tokenId);
            return; // no one placed a bid before it ended --> buyNow at basePrice
        }
        IERC721(collection).safeTransferFrom(item.seller, winner, tokenId);
        // Transfer the funds to the pool
        // (bool success, ) = poolAddr.call{value: item.highestBid}("");
        // require(success, "Transfer to pool failed");

        // BoughtReceipt storage receipt = BoughtReceipt(winner, collection, tokenId, item.highestBid, item.originalOwner, block.timestamp);
        boughtList.push(BoughtReceipt(winner, collection, tokenId, item.highestBid, item.originalOwner, block.timestamp));
        boughtIndex[collection][tokenId] = boughtList.length - 1;

        iLendingPool.liquidate{ value: item.highestBid }(item.originalOwner, collection, tokenId, item.highestBid);
        emit AuctionWon(winner, collection, tokenId, item.highestBid);
        deleteListing(collection, tokenId);
    }

    function endAllConcludedAuctions() public {
        for (uint i = 0; i < listings.length; i++) {
            if (!listings[i].buyNow) {
                endAuction(listings[i].collection, listings[i].tokenId);
            } 
        }
    }

    // purchase an NFT (user purchases from CollateralManager) ??-F
    function purchase(address buyer, address collection, uint256 tokenId) external payable onlyPortal {
        require(isListing(collection, tokenId), "NFT not listed");
        Listing storage item = listings[listingIndex[collection][tokenId]];
        // require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        endAuction(collection, tokenId);
        uint256 amount = msg.value;
        require(item.buyNow, "[*ERROR*] NFT is not available to be purchased, it is still being auctioned");
        require(msg.value >= item.basePrice, "[*ERROR*] Insufficient funds!");

        // Update balances and transfer NFT
        IERC721 token = IERC721(collection);
        token.safeTransferFrom(item.seller, buyer, tokenId);
        // send funds back to the pool

        // BoughtReceipt storage receipt = BoughtReceipt(buyer, collection, tokenId, amount, item.originalOwner, block.timestamp);
        boughtList.push(BoughtReceipt(buyer, collection, tokenId, amount, item.originalOwner, block.timestamp));
        boughtIndex[collection][tokenId] = boughtList.length - 1;

        iLendingPool.liquidate{ value: msg.value }(item.originalOwner, collection, tokenId, amount);
        // Remove the listing
        deleteListing(collection, tokenId);
        emit NFTPurchased(collection, tokenId, msg.value, buyer, block.timestamp);
    }

    function getListingCollectionAddr() public view returns (address[] memory) {
        address[] memory addresses = new address[](listings.length);
        for (uint256 i = 0; i < listings.length; i++) {
            addresses[i] = listings[i].collection;
        }
        return addresses;
    }

    function getListingTokenIds() public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](listings.length);
        for (uint256 i = 0; i < listings.length; i++) {
            tokenIds[i] = listings[i].tokenId;
        }
        return tokenIds;
    }

    function getListingData(address collection, uint256 tokenId) public view returns (
        uint256 basePrice,
        uint256 auctionStarted,
        uint256 auctionEnds,
        uint256 highestBid,
        bool buyNow
    ) {
        if (!isListingMapping[collection][tokenId]) {
            return (0, 0, 0, 0, false);
        }
        uint256 index = listingIndex[collection][tokenId];
        Listing memory listing = listings[index];
        if (listing.collection == collection && listing.tokenId == tokenId) {
            return (listing.basePrice, listing.auctionStarted, listing.auctionEnds, listing.highestBid, listing.buyNow);
        } else {
            return (0, 0, 0, 0, false);
        }
    }

    // Withdraw funds NOT NEEDED
    // function withdraw(address payable destinationAddress) public onlyCollateralManager {
    //     require(0 < balances[destinationAddress], "[*ERROR*] nothing to be withdrawed");
    //     (bool success, ) = destinationAddress.call{value: amount}("");
    //     require(success, "[*ERROR*] Withdrawal failed!");
    //     emit Withdrawal(destinationAddress, balances[destinationAddress]);
    //     balances[destinationAddress] = 0;
    // }

    //////// ** CONTRACT MANAGER FUNCTIONS ** ///////////
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}

    // for the liquidator to get the data ?? not necessary
    // @Helper
    

    // called within this function to see if this nft is currently listed
    // called by CM to check on its status

    // function notPurchased(address collection, uint256 tokenId) external returns (bool) {
    //     Listing storage item = listings[collection][tokenId];
    //     uint256 timeNow = block.timestamp;
    //     if 
    // }

}