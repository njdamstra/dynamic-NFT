// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct. // should we not use tokenId instead of nttId as uint256? -F
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public poolBalances; //dont understand this mapping why do we track balances of users? -F

    // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated
    struct Listing {
        address seller; // in the case of one llending pool, this will always be the same (CM)
        uint256 basePrice; // first bid has to be at least this amount
        uint256 auctionStarted; // when listing was created
        uint256 auctionEnds; // how long auction will last
        uint256 highestBid; // highest bid if one 
        address highestBidder; // addr of the last bid
        bool buyNow; // if auction duration has passed, then the liquidator can buy immediately at basePrice
    } // TODO: might delete buyNow since it's not necessary


    address public collateralManager;
    address public pool;
    uint public numCollections;

    constructor(address _collateralManager, address _pool) {
        collateralManager = _collateralManager; // caller of contract is the owner of the NFT
        // must make this the address of the collateralManager
        pool = _pool; // where we transfer money to
        numCollections = 0;
        poolBalances[pool] = 0;
    }

    modifier onlyCollateralManager() {
        require(msg.sender == collateralManager, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    // Events for transparency
    event NFTListed(address indexed collection, uint256 indexed tokenId, uint256 basePrice, address seller, bool auction, uint256 timestamp);
    event NFTDelisted(address indexed collection, uint256 indexed tokenId, uint256 timestamp);
    event NFTPurchased(address indexed collection, uint256 indexed tokenId, uint256 price, address buyer, uint256 timestamp);
    event Withdrawal(address indexed destination, uint256 amount);

    // Add an NFT listing
    function addListing(uint256 basePrice, address collection, uint256 tokenId, bool auction, uint256 duration) public onlyCollateralManager {
        IERC721 token = IERC721(collection);
        // Ensure the NFT is owned and approved by the collateralManager
        require(token.ownerOf(tokenId) == collateralManager, "[*ERROR*] Caller must own the NFT!");
        require(token.isApproved(collateralManager, address(this), tokenId), "[*ERROR*] Contract is not approved!"); // might delete this so that approval only happens when purchased
        // check for no redundant listings currently; 
        require(!isListed(collection, tokenId), "[*ERROR*] token is already listed");
        // Add the listing
        uint256 timestamp = block.timestamp();
        uint256 auctionEnds = timestamp + duration;
        listings[collection][tokenId] = Listing(collateralManager, basePrice, timestamp, auctionEnds, 0, address(0), !auction);

        // create a listing event
        emit NFTListed(collection, tokenId, basePrice, collateralManager, auction, timestamp);
    }

    // Delist an NFT 
    // (this shouldn't be called when some purchased the nft, this should only be called when the borrower wants to reedem there nft)
    function delist(address collection, uint256 tokenId) public onlyCollateralManager {
        // require(checkTokenId(collection, tokenId), "[*ERROR*] NFT is not listed!");
        require(isListed(collection, tokenId), "[*ERROR*] NFT is not listed!");
        // Remove the listing
        delete listings[collection][tokenId];
        // remove from tokenIdList 
        // tokenIdList[collection][0] -= 1;
        emit NFTDelisted(collection, tokenId);
    }

    function placeBid(address collection, uint256 tokenId) external payable {
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
        item.highestBidder = msg.sender;
    }

    //TODO: liquidate at highest bid
    function endAuction(address collection, uint256 tokenId) public {
        // called only if auction duration has been completed.
        // if there is a bid, automatically transfer NFT to highest bidders address
        // if no bid made, change buyNow bool from false to true
        require(isListed(collection, tokenId), "Token not listed for sale")
        Listing storage item = listings[collection][tokenId]
        require(item.auctionEnd <= block.timestamp, "Auction has not ended");
        // now we know auction can be ended
        address winner = item.highestBidder;
        if (winner == address(0)) {
            listings[collection][tokenId].buyNow = true;
            return; // no one placed a bid before it ended --> buyNow at basePrice
        }
        IERC721(collection).safeTransferFrom(item.seller, item.highestBidder, tokenId);
        // Transfer the funds to the pool
        (bool success, ) = pool.call{value: item.highestBid}("");
        require(success, "Transfer to pool failed");

        emit NFTAuctionEnded(collection, tokenId, item.highestBidder, item.highestBid, block.timestamp);
        delete listings[collection][tokenId];
    }



    // purchase an NFT (user purchases from CollateralManager) ??-F
    function purchase(address collection, uint256 tokenId) public payable {
        require(isListed(collection, tokenId), "NFT not listed");
        Listing memory item = listings[collection][tokenId];
        // require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        endAuction(collection, tokenId);
        require(item.buyNow, "[*ERROR*] NFT is not available to be purchased, it is still being auctioned");
        require(msg.value >= item.basePrice, "[*ERROR*] Insufficient funds!");

        // Update balances and transfer NFT
        IERC721 token = IERC721(collection);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);
        // send funds back to the pool
        (bool success, ) = pool.call{value: msg.value}("");
        require(success, "Transfer to pool failed");
        // Remove the listing
        delete listings[collection][tokenId];
        emit NFTPurchased(collection, tokenId, item.price, msg.sender);
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


    // helper functions:

    // for the liquidator to get the data ?? not necessary
    function viewListing(address collection, uint256 tokenId) public view returns (struct) {
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

    // currently not being used
    // function isAuction(address collection, uint256 tokenId) public view returns (bool) { 
    //     return !listings[collection][tokenId].buyNow;
    // }

    // // returns true if collection is already in collection list
    // function checkCollection(address collection) private returns (bool) {
    //     for (uint i = 0; i < numCollections; i++) {
    //         if (collectionList[i] == collection) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    // // returns true if token already is up for sale and listed
    // function checkTokenId(address collection, uint256 tokenId) private returns (bool) {
    //     if (!checkCollection(collection)) {
    //         return false; // collection isn't added yet so token is definitely not up for sale
    //     }
    //     for (uint i = 1; i < tokenIdList[collection][0] + 1; i ++) { // i = 1 because first entry is always the length of the tokenIdList
    //         if (tokenIdList[collection][i] == tokenId) {
    //             return true;
    //         }
    //     }
    //     return false;
    }

}